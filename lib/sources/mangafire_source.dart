import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'manga_source.dart';

/// Parser API MangaFire. Situs ini tidak mengirim katalog/chapter lewat HTML;
/// semua data reader diambil dari endpoint JSON resminya.
class MangaFireSource implements MangaSource {
  MangaFireSource({
    this.name = 'MangaFire',
    this.baseUrl = 'https://mangafire.to',
    String? lang,
    http.Client? client,
  }) : lang = _normalizeLang(lang),
       _client = client ?? http.Client();

  @override
  final String name;

  @override
  final String baseUrl;

  final String lang;
  final http.Client _client;

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Referer': '${_baseUri.toString().replaceAll(RegExp(r'/$'), '')}/',
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
  };

  Uri get _baseUri => Uri.parse(baseUrl);

  static String _normalizeLang(String? raw) {
    final value = raw?.trim().toLowerCase();
    return switch (value) {
      'es-419' => 'es-la',
      'pt-br' => 'pt-br',
      'es' || 'fr' || 'ja' || 'pt' => value!,
      _ => 'en',
    };
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = _baseUri.resolve(path).replace(queryParameters: query);
    late final http.Response response;
    try {
      response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
    } catch (error) {
      throw MangaSourceException('Gagal menghubungi $name: $error');
    }
    if (response.statusCode != 200) {
      throw MangaSourceException(
        '$name mengembalikan status ${response.statusCode}.',
      );
    }
    try {
      return (jsonDecode(response.body) as Map).cast<String, dynamic>();
    } catch (_) {
      throw MangaSourceException('Respons API $name tidak dikenali.');
    }
  }

  @override
  Future<SourceMangaPage> fetchPopular(int page) =>
      _fetchTitles(page: page, orderKey: 'views_30d');

  @override
  Future<SourceMangaPage> fetchLatest(int page) =>
      _fetchTitles(page: page, orderKey: 'chapter_updated_at');

  @override
  Future<SourceMangaPage> fetchSearch(String query, int page) =>
      _fetchTitles(page: page, keyword: query);

  Future<SourceMangaPage> _fetchTitles({
    required int page,
    String? orderKey,
    String? keyword,
  }) async {
    final json = await _getJson(
      '/api/titles',
      query: {
        if (orderKey != null) 'order[$orderKey]': 'desc',
        if (keyword != null && keyword.trim().isNotEmpty)
          'keyword': keyword.trim(),
        'page': '$page',
        'limit': '50',
      },
    );
    final mangas = _items(json).map(_mangaFromMap).whereType<SourceManga>();
    final meta = _map(json['meta']);
    final hasNext =
        meta?['hasNext'] == true ||
        meta?['has_next'] == true ||
        ((meta?['lastPage'] as num?)?.toInt() ??
                (meta?['last_page'] as num?)?.toInt() ??
                page) >
            page;
    return SourceMangaPage(mangas: mangas.toList(), hasNextPage: hasNext);
  }

  SourceManga? _mangaFromMap(Map<String, dynamic> map) {
    final hid = '${map['hid'] ?? ''}'.trim();
    final title = '${map['title'] ?? ''}'.trim();
    if (hid.isEmpty || title.isEmpty) return null;
    final slug = '${map['slug'] ?? ''}'.trim();
    final poster = _map(map['poster']);
    final thumbnail = _firstString([
      poster?['large'],
      poster?['medium'],
      poster?['small'],
    ]);
    return SourceManga(
      url: '/title/$hid${slug.isEmpty ? '' : '-$slug'}',
      title: title,
      thumbnailUrl: thumbnail == null ? null : _absolute(thumbnail),
      headers: {'Referer': _headers['Referer']!},
    );
  }

  @override
  Future<SourceMangaDetails> fetchMangaDetails(String mangaUrl) async {
    final json = await _getJson('/api/titles/${_hidFromUrl(mangaUrl)}');
    final data = _map(json['data']);
    if (data == null) {
      throw MangaSourceException('Detail manga $name tidak dikenali.');
    }
    final poster = _map(data['poster']);
    final synopsis = _string(data['synopsisHtml']);
    final type = _string(data['type']);
    final genres = <String>[
      if (type != null && type.isNotEmpty) _capitalized(type),
      ..._entityTitles(data['genres']),
      ..._entityTitles(data['themes']),
    ];
    return SourceMangaDetails(
      description: synopsis == null
          ? null
          : (html_parser.parseFragment(synopsis).text ?? '').trim(),
      author: _entityTitles(data['authors']).join(', '),
      artist: _entityTitles(data['artists']).join(', '),
      genres: genres.toSet().toList(),
      status: switch (_string(data['status'])?.toLowerCase()) {
        'releasing' => SourceMangaStatus.ongoing,
        'finished' => SourceMangaStatus.completed,
        'on_hiatus' => SourceMangaStatus.hiatus,
        'discontinued' => SourceMangaStatus.cancelled,
        _ => SourceMangaStatus.unknown,
      },
      thumbnailUrl: _firstString([
        poster?['large'],
        poster?['medium'],
        poster?['small'],
      ]),
    );
  }

  @override
  Future<List<SourceChapter>> fetchChapterList(String mangaUrl) async {
    final hid = _hidFromUrl(mangaUrl);
    final mangaPath = Uri.parse(
      _absolute(mangaUrl),
    ).path.replaceAll(RegExp(r'/$'), '');
    final chapters = <SourceChapter>[];
    var page = 1;
    var lastPage = 1;
    do {
      final json = await _getJson(
        '/api/titles/$hid/chapters',
        query: {
          'language': lang,
          'sort': 'number',
          'order': 'desc',
          'page': '$page',
          'limit': '200',
        },
      );
      for (final chapter in _items(json)) {
        final id = (chapter['id'] as num?)?.toInt();
        final number = (chapter['number'] as num?)?.toDouble();
        if (id == null || number == null) continue;
        final numberLabel = number == number.roundToDouble()
            ? '${number.toInt()}'
            : '$number';
        final title = _string(chapter['name']);
        final createdAt = (chapter['createdAt'] as num?)?.toInt();
        chapters.add(
          SourceChapter(
            url: '$mangaPath/$id-chapter-$numberLabel-$lang',
            name:
                'Ch. $numberLabel${title == null || title.isEmpty ? '' : ' - $title'}',
            dateUpload: createdAt == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
          ),
        );
      }
      final meta = _map(json['meta']);
      lastPage =
          (meta?['lastPage'] as num?)?.toInt() ??
          (meta?['last_page'] as num?)?.toInt() ??
          1;
      page++;
    } while (page <= lastPage && page <= 20);
    if (chapters.isEmpty) {
      throw MangaSourceException('Daftar chapter $name tidak ditemukan.');
    }
    return chapters;
  }

  @override
  Future<List<SourcePage>> fetchPageList(String chapterUrl) async {
    final lastSegment = Uri.parse(_absolute(chapterUrl)).pathSegments.last;
    final chapterId = lastSegment.split('-').first;
    final json = await _getJson('/api/chapters/$chapterId');
    final data = _map(json['data']);
    final rawPages = data?['pages'];
    if (rawPages is! List) {
      throw MangaSourceException('Gambar chapter $name tidak dikenali.');
    }
    final pages = <SourcePage>[];
    for (final raw in rawPages) {
      final url = _string(_map(raw)?['url']);
      if (url == null || url.isEmpty) continue;
      pages.add(
        SourcePage(
          index: pages.length,
          imageUrl: _absolute(url),
          headers: {'Referer': _headers['Referer']!},
        ),
      );
    }
    if (pages.isEmpty) {
      throw MangaSourceException('Gambar chapter $name tidak ditemukan.');
    }
    return pages;
  }

  String _hidFromUrl(String raw) {
    final last = Uri.parse(_absolute(raw)).pathSegments.last;
    if (last.contains('.')) return last.split('.').last;
    if (last.contains('-')) return last.split('-').first;
    return last;
  }

  String _absolute(String raw) => _baseUri.resolve(raw).toString();

  List<Map<String, dynamic>> _items(Map<String, dynamic> json) {
    final raw = json['items'];
    if (raw is! List) return const [];
    return raw.map(_map).whereType<Map<String, dynamic>>().toList();
  }

  Map<String, dynamic>? _map(Object? value) =>
      value is Map ? value.cast<String, dynamic>() : null;

  String? _string(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _firstString(Iterable<Object?> values) {
    for (final value in values) {
      final string = _string(value);
      if (string != null) return string;
    }
    return null;
  }

  List<String> _entityTitles(Object? value) {
    if (value is! List) return const [];
    return value
        .map(_map)
        .whereType<Map<String, dynamic>>()
        .map((item) => _string(item['title']))
        .whereType<String>()
        .toList();
  }

  String _capitalized(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}
