import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../data/source_session_store.dart';
import 'manga_source.dart';

/// Parser native untuk Asura Scans modern (Astro + API).
///
/// Listing/search/chapter metadata tersedia lewat API publik Asura, sedangkan
/// detail dan halaman chapter juga dibawa sebagai props SSR di HTML Astro.
class AsuraSource implements MangaSource {
  AsuraSource({http.Client? client}) : _client = client ?? http.Client();

  @override
  String get name => 'Asura Scans';

  @override
  String get baseUrl => 'https://asurascans.com';

  static const _apiBase = 'https://api.asurascans.com';

  final http.Client _client;

  Map<String, String> get _headers => {
    'Referer': '$baseUrl/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    ...SourceSessionStore.headersFor(baseUrl),
  };

  Map<String, String> get _imageHeaders => {
    ..._headers,
    'Accept':
        'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
  };

  Future<http.Response> _get(Uri url) async {
    try {
      return await _client.get(url, headers: _headers);
    } catch (e) {
      throw MangaSourceException('Gagal menghubungi $name: $e');
    }
  }

  Future<Document> _getHtml(Uri url) async {
    final response = await _get(url);
    if (response.statusCode != 200) {
      throw MangaSourceException(
        '$name mengembalikan status ${response.statusCode}.',
      );
    }
    return html_parser.parse(response.body);
  }

  Future<Map<String, dynamic>> _getJson(Uri url) async {
    final response = await _get(url);
    if (response.statusCode != 200) {
      throw MangaSourceException(
        '$name mengembalikan status ${response.statusCode}.',
      );
    }
    return (jsonDecode(response.body) as Map).cast<String, dynamic>();
  }

  String _absUrl(String path) => Uri.parse(baseUrl).resolve(path).toString();

  String _seriesSlug(String mangaUrl) {
    final segments = Uri.parse(mangaUrl).pathSegments;
    final index = segments.indexOf('comics');
    if (index == -1 || index + 1 >= segments.length) {
      throw const MangaSourceException('URL Asura tidak valid.');
    }
    return segments[index + 1];
  }

  Future<SourceMangaPage> _browse(int page, String order) async {
    final url = Uri.parse(
      '$baseUrl/browse',
    ).replace(queryParameters: {'page': '$page', 'order': order});
    final document = await _getHtml(url);
    final props = _propsWithKey(document, 'initialSeries');
    final series = (props['initialSeries'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final mangas = series.map(_mangaFromMap).toList();
    final total = (props['totalCount'] as num?)?.toInt() ?? mangas.length;
    return SourceMangaPage(
      mangas: mangas,
      hasNextPage: page * (mangas.isEmpty ? 1 : mangas.length) < total,
    );
  }

  SourceManga _mangaFromMap(Map<String, dynamic> map) {
    final url = map['public_url'] as String? ?? map['publicUrl'] as String?;
    return SourceManga(
      url: _absUrl(url ?? '/comics/${map['slug'] ?? ''}'),
      title: map['title'] as String? ?? '',
      thumbnailUrl: map['cover'] as String? ?? map['cover_url'] as String?,
    );
  }

  @override
  Future<SourceMangaPage> fetchPopular(int page) => _browse(page, 'popular');

  @override
  Future<SourceMangaPage> fetchLatest(int page) => _browse(page, 'update');

  @override
  Future<SourceMangaPage> fetchSearch(String query, int page) async {
    // Asura search endpoint doesn't paginate in the current web app; keep
    // page 1 as the real result and later pages empty.
    if (page > 1) {
      return const SourceMangaPage(mangas: [], hasNextPage: false);
    }
    final json = await _getJson(
      Uri.parse('$_apiBase/api/search').replace(queryParameters: {'q': query}),
    );
    final items = (json['data'] as List? ?? const []).cast<Map>();
    return SourceMangaPage(
      mangas: items
          .map((m) => _mangaFromMap(m.cast<String, dynamic>()))
          .toList(),
      hasNextPage: false,
    );
  }

  @override
  Future<SourceMangaDetails> fetchMangaDetails(String mangaUrl) async {
    final document = await _getHtml(Uri.parse(mangaUrl));
    final props = _propsWithKey(document, 'coverUrl');
    final rawDescription = props['description'] as String?;
    final genres = (props['genres'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map((g) => g['name'] as String? ?? '')
        .where((g) => g.isNotEmpty)
        .toList();
    return SourceMangaDetails(
      description: rawDescription == null
          ? null
          : html_parser.parse(rawDescription).body?.text.trim(),
      author: props['author'] as String?,
      artist: props['artist'] as String?,
      genres: genres,
      status: _parseStatus(props['status'] as String?),
      thumbnailUrl: props['coverUrl'] as String?,
    );
  }

  SourceMangaStatus _parseStatus(String? status) => switch (status) {
    'ongoing' => SourceMangaStatus.ongoing,
    'completed' => SourceMangaStatus.completed,
    'hiatus' => SourceMangaStatus.hiatus,
    'cancelled' || 'canceled' => SourceMangaStatus.cancelled,
    _ => SourceMangaStatus.unknown,
  };

  @override
  Future<List<SourceChapter>> fetchChapterList(String mangaUrl) async {
    final seriesSlug = _seriesSlug(mangaUrl);
    final json = await _getJson(
      Uri.parse('$_apiBase/api/series/$seriesSlug/chapters'),
    );
    final items = (json['data'] as List? ?? const []).cast<Map>();
    return [
      for (final item in items.map((m) => m.cast<String, dynamic>()))
        if (item['is_locked'] != true && item['is_premium'] != true)
          SourceChapter(
            url:
                '$baseUrl/comics/$seriesSlug/chapter/${item['slug'] ?? _chapterNumber(item)}',
            name: [
              'Chapter ${_chapterNumber(item)}',
              if ((item['title'] as String?)?.isNotEmpty ?? false)
                item['title'],
            ].join(' · '),
            dateUpload: DateTime.tryParse(
              item['published_at'] as String? ?? '',
            ),
          ),
    ];
  }

  String _chapterNumber(Map<String, dynamic> item) {
    final number = item['number'];
    if (number is int) return '$number';
    if (number is double) {
      return number == number.roundToDouble() ? '${number.toInt()}' : '$number';
    }
    return '$number';
  }

  @override
  Future<List<SourcePage>> fetchPageList(String chapterUrl) async {
    final document = await _getHtml(Uri.parse(chapterUrl));
    final props = _propsWithKey(document, 'pages');
    if (props['isLocked'] == true || props['isPremium'] == true) {
      throw const MangaSourceException('Chapter Asura ini masih terkunci.');
    }
    final pages = (props['pages'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    if (pages.isEmpty) {
      throw const MangaSourceException('Gambar chapter Asura belum tersedia.');
    }
    return [
      for (var i = 0; i < pages.length; i++)
        SourcePage(
          index: i,
          imageUrl: pages[i]['url'] as String? ?? '',
          width: (pages[i]['width'] as num?)?.toInt(),
          height: (pages[i]['height'] as num?)?.toInt(),
          headers: _imageHeaders,
        ),
    ].where((p) => p.imageUrl.isNotEmpty).toList();
  }

  Map<String, dynamic> _propsWithKey(Document document, String key) {
    for (final island in document.querySelectorAll('astro-island')) {
      final raw = island.attributes['props'];
      if (raw == null || !raw.contains(key)) continue;
      final decoded = _decodeAstroValue(jsonDecode(raw));
      if (decoded is Map && decoded.containsKey(key)) {
        return decoded.cast<String, dynamic>();
      }
    }
    throw MangaSourceException('Data $name tidak lengkap.');
  }

  /// Decode format serialized props Astro:
  /// `[0, value]` = value, `[1, [items...]]` = array, object values nested.
  dynamic _decodeAstroValue(dynamic value) {
    if (value is List && value.length == 2 && value.first is int) {
      return switch (value.first as int) {
        0 => _decodeAstroValue(value[1]),
        1 => (value[1] as List).map(_decodeAstroValue).toList(),
        _ => _decodeAstroValue(value[1]),
      };
    }
    if (value is Map) {
      return {
        for (final entry in value.entries)
          '${entry.key}': _decodeAstroValue(entry.value),
      };
    }
    if (value is List) return value.map(_decodeAstroValue).toList();
    return value;
  }
}
