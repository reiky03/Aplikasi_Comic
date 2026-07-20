import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../data/source_session_store.dart';
import 'manga_source.dart';

/// Parser generik untuk reader SvelteKit yang merender data komik ke HTML.
///
/// Soul Scans memakai pola ini, tapi parsernya sengaja tidak dikunci ke nama
/// domain: payload `data-sveltekit-fetched`, route `/comic/...`, dan field
/// `image_url`/`poster_image_url` juga dipakai beberapa situs SvelteKit lain.
class SvelteKitComicSource implements MangaSource {
  SvelteKitComicSource({
    required this.name,
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  final String name;

  @override
  final String baseUrl;

  final http.Client _client;

  Map<String, String> get _headers => {
    'Referer': '$baseUrl/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    ...SourceSessionStore.headersFor(baseUrl),
  };

  Uri _absUri(String raw) => Uri.parse(baseUrl).resolve(raw);

  String _absUrl(String raw) => _normalizeImageUrl(_absUri(raw).toString());

  Future<Document> _getHtml(String rawUrl) async {
    final url = _absUri(rawUrl);
    late final http.Response response;
    try {
      response = await _client
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw MangaSourceException('Gagal menghubungi $name: $e');
    }
    if (response.statusCode != 200) {
      throw MangaSourceException(
        '$name mengembalikan status ${response.statusCode}.',
      );
    }
    return html_parser.parse(response.body);
  }

  @override
  Future<SourceMangaPage> fetchPopular(int page) async {
    try {
      final apiPage = await _fetchApiList(page: page, sort: 'popular');
      if (apiPage != null) return apiPage;
    } catch (_) {
      // Lanjut ke fallback HTML.
    }
    return _fetchList(
      page: page,
      // Homepage Soulscans adalah fallback popular yang valid, walau ringkas.
      paths: const ['/', '/allcomic', '/comic'],
    );
  }

  @override
  Future<SourceMangaPage> fetchLatest(int page) async {
    // Endpoint ini adalah data yang dipakai halaman All Comic sendiri. Lebih
    // akurat daripada menebak urutan dari HTML/section yang ikut ter-render.
    try {
      final apiPage = await _fetchApiList(page: page, sort: 'latest');
      if (apiPage != null) return apiPage;
    } catch (_) {
      // Situs lain yang kebetulan memakai pola SvelteKit boleh lanjut ke
      // fallback HTML di bawah.
    }

    // Jangan jatuh ke /comic atau homepage karena keduanya hanya section
    // ringkas 4 item dan bukan daftar Terbaru.
    return _fetchList(
      page: page,
      sort: 'latest',
      order: 'desc',
      paths: const ['/allcomic'],
    );
  }

  @override
  Future<SourceMangaPage> fetchSearch(String query, int page) => _fetchList(
    page: page,
    query: query,
    paths: const ['/allcomic', '/comic', '/search'],
  );

  Future<SourceMangaPage> _fetchList({
    required int page,
    required List<String> paths,
    String query = '',
    String? sort,
    String? order,
  }) async {
    Object? lastError;
    for (final path in paths) {
      try {
        final queryParameters = <String, String>{
          if (query.trim().isNotEmpty) 'search': query.trim(),
          if (page > 1) 'page': '$page',
        };
        if (sort != null) queryParameters['sort'] = sort;
        if (order != null) queryParameters['order'] = order;
        final uri = _absUri(path).replace(queryParameters: queryParameters);
        final document = await _getHtml(uri.toString());
        var mangas = _mangasFromDocument(document);
        if (query.trim().isNotEmpty) {
          final needle = query.trim().toLowerCase();
          mangas = mangas
              .where((manga) => manga.title.toLowerCase().contains(needle))
              .toList();
        }
        if (mangas.isNotEmpty) {
          return SourceMangaPage(
            mangas: mangas.take(40).toList(),
            hasNextPage: mangas.length >= 40,
          );
        }
      } catch (e) {
        lastError = e;
      }
    }
    throw MangaSourceException(
      'Struktur daftar komik $name belum dikenali'
      '${lastError == null ? '' : ': $lastError'}',
    );
  }

  Future<SourceMangaPage?> _fetchApiList({
    required int page,
    required String sort,
  }) async {
    final uri = _absUri('/api/search').replace(
      queryParameters: {
        'type': 'COMIC',
        'limit': '50',
        'page': '$page',
        'sort': sort,
        'order': 'desc',
      },
    );
    final response = await _client
        .get(
          uri,
          headers: {
            ..._headers,
            'Accept': 'application/json, text/plain, */*',
            'Cache-Control': 'no-cache',
          },
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body);
    final rawData = decoded is Map ? decoded['data'] : null;
    if (rawData is! List) return null;

    final mangas = <SourceManga>[];
    final seen = <String>{};
    for (final raw in rawData) {
      if (raw is! Map) continue;
      final map = <String, Object?>{
        for (final entry in raw.entries) '${entry.key}': entry.value,
      };
      final title = _stringValue(map, const ['title', 'name']);
      final slug = _stringValue(map, const [
        'slug',
        'comic_slug',
        'series_slug',
      ]);
      final image = _imageValue(map, const [
        'poster_image_url',
        'cover_url',
        'thumbnail_url',
        'image_url',
      ]);
      if (title == null || slug == null || image == null) continue;
      final url = _absUrl('/comic/$slug');
      if (!seen.add(url)) continue;
      mangas.add(
        SourceManga(
          url: url,
          title: title,
          thumbnailUrl: image,
          headers: _headers,
        ),
      );
    }
    if (mangas.isEmpty) return null;
    return SourceMangaPage(mangas: mangas, hasNextPage: rawData.length >= 50);
  }

  @override
  Future<SourceMangaDetails> fetchMangaDetails(String mangaUrl) async {
    final document = await _getHtml(mangaUrl);
    final metaDescription = document
        .querySelector(
          'meta[name="description"], meta[property="og:description"]',
        )
        ?.attributes['content']
        ?.trim();
    final metaImage = document
        .querySelector('meta[property="og:image"]')
        ?.attributes['content'];

    String? description = metaDescription;
    String? thumbnailUrl = metaImage == null ? null : _absUrl(metaImage);
    SourceMangaStatus status = SourceMangaStatus.unknown;
    var genres = <String>[];
    for (final map in _mapsFromDocument(document)) {
      description ??= _stringValue(map, const [
        'description',
        'synopsis',
        'summary',
      ]);
      thumbnailUrl ??= _imageValue(map, const [
        'poster_image_url',
        'cover_url',
        'thumbnail_url',
        'image_url',
      ]);
      if (genres.isEmpty) {
        genres = _stringListValue(map, const ['genres', 'genre', 'tags']);
      }
      final rawStatus = _stringValue(map, const [
        'comic_status',
        'status',
        'series_status',
      ])?.toLowerCase();
      status = _statusFrom(rawStatus) ?? status;
    }

    return SourceMangaDetails(
      description: description?.isEmpty == true ? null : description,
      author: null,
      artist: null,
      genres: genres,
      status: status,
      thumbnailUrl: thumbnailUrl,
    );
  }

  @override
  Future<List<SourceChapter>> fetchChapterList(String mangaUrl) async {
    final document = await _getHtml(mangaUrl);
    final seen = <String>{};
    final chapters = <SourceChapter>[];
    final seriesSlug = _seriesSlug(mangaUrl);

    // Payload chapter punya label asli (mis. "Chapter 1"). Parse dulu agar
    // tombol navigasi "First chapter" tidak mengambil alih nama chapter.
    for (final map in _mapsFromDocument(document)) {
      final slug = _stringValue(map, const ['chapter_slug', 'slug']);
      if (slug == null || !slug.toLowerCase().contains('chapter')) continue;
      final href = _stringValue(map, const [
        'url',
        'href',
        'link',
        'chapter_url',
      ]);
      final rawUrl =
          href ??
          (seriesSlug == null ? null : '/comic/$seriesSlug/chapter/$slug');
      if (rawUrl == null) continue;
      final url = _absUrl(rawUrl);
      if (!seen.add(url)) continue;
      chapters.add(
        SourceChapter(
          url: url,
          name:
              _stringValue(map, const [
                'chapter_name',
                'chapter_title',
                'title',
                'name',
                'number',
              ]) ??
              _chapterName(rawUrl),
          dateUpload: _dateValue(map),
        ),
      );
    }

    for (final anchor in document.querySelectorAll('a[href*="/chapter/"]')) {
      final href = anchor.attributes['href'];
      if (href == null) continue;
      final url = _absUrl(href);
      if (!seen.add(url)) continue;
      final label = anchor.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      chapters.add(
        SourceChapter(
          url: url,
          name: label.isEmpty ? _chapterName(href) : label,
        ),
      );
    }

    if (chapters.isEmpty) {
      throw MangaSourceException('Daftar chapter $name belum dikenali.');
    }
    return chapters;
  }

  @override
  Future<List<SourcePage>> fetchPageList(String chapterUrl) async {
    final document = await _getHtml(chapterUrl);
    final referer = _absUrl(chapterUrl);
    final headers = {..._headers, 'Referer': referer};
    final seen = <String>{};
    final pages = <SourcePage>[];

    for (final image in document.querySelectorAll('main img, article img')) {
      final raw =
          image.attributes['src'] ??
          image.attributes['data-src'] ??
          image.attributes['data-lazy-src'];
      final url = raw == null ? null : _pageImageUrl(raw);
      if (url == null || !seen.add(url)) continue;
      pages.add(
        SourcePage(index: pages.length, imageUrl: url, headers: headers),
      );
    }

    for (final map in _pageMapsFromDocument(document)) {
      final raw = _stringValue(map, const [
        'image_url',
        'imageUrl',
        'src',
        'url',
        'path',
      ]);
      final url = raw == null ? null : _pageImageUrl(raw);
      if (url == null || !seen.add(url)) continue;
      pages.add(
        SourcePage(index: pages.length, imageUrl: url, headers: headers),
      );
    }

    if (pages.isEmpty) {
      throw MangaSourceException('Gambar chapter $name belum dikenali.');
    }
    return pages;
  }

  List<SourceManga> _mangasFromDocument(Document document) {
    final result = <SourceManga>[];
    final seen = <String>{};
    for (final map in _mapsFromDocument(document)) {
      final title = _stringValue(map, const ['title', 'name']);
      final slug = _stringValue(map, const [
        'slug',
        'comic_slug',
        'series_slug',
      ]);
      final image = _imageValue(map, const [
        'poster_image_url',
        'cover_url',
        'thumbnail_url',
        'image_url',
      ]);
      if (title == null || slug == null || image == null) continue;
      if (slug.toLowerCase().contains('chapter')) continue;
      final url = _absUrl('/comic/$slug');
      if (!seen.add(url)) continue;
      result.add(
        SourceManga(
          url: url,
          title: title,
          thumbnailUrl: image,
          headers: _headers,
        ),
      );
    }
    for (final anchor in document.querySelectorAll('a[href^="/comic/"]')) {
      final href = anchor.attributes['href'];
      if (href == null || href.contains('/chapter/')) continue;
      final url = _absUrl(href);
      if (!seen.add(url)) continue;
      final image = anchor.querySelector('img');
      final title =
          anchor.attributes['title'] ??
          image?.attributes['alt'] ??
          anchor.text.trim();
      if (title.trim().length < 2) continue;
      result.add(
        SourceManga(
          url: url,
          title: title.trim(),
          thumbnailUrl: image == null
              ? null
              : _pageImageUrl(
                  image.attributes['src'] ?? image.attributes['data-src'] ?? '',
                ),
          headers: _headers,
        ),
      );
    }
    return result;
  }

  List<Map<String, Object?>> _mapsFromDocument(Document document) {
    final values = <Object?>[];
    for (final script in document.querySelectorAll(
      'script[type="application/json"], script[data-sveltekit-fetched]',
    )) {
      final raw = script.text.trim();
      if (raw.isEmpty || raw.length > 260000) continue;
      try {
        values.add(jsonDecode(raw));
      } on FormatException {
        // Payload ini kadang berupa JavaScript wrapper; DOM tetap dicoba.
      }
    }
    final result = <Map<String, Object?>>[];
    var visited = 0;
    void walk(Object? value, int depth) {
      if (depth > 10 || visited++ > 1800 || result.length > 800) return;
      if (value is Map) {
        final map = <String, Object?>{
          for (final entry in value.entries) '${entry.key}': entry.value,
        };
        result.add(map);
        for (final nested in map.values) {
          walk(nested, depth + 1);
        }
      } else if (value is List) {
        for (final nested in value) {
          walk(nested, depth + 1);
        }
      } else if (value is String) {
        final trimmed = value.trim();
        if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
          try {
            walk(jsonDecode(trimmed), depth + 1);
          } on FormatException {
            // Bukan JSON lengkap.
          }
        }
      }
    }

    for (final value in values) {
      walk(value, 0);
    }
    return result;
  }

  List<Map<String, Object?>> _pageMapsFromDocument(Document document) {
    final result = <Map<String, Object?>>[];
    for (final map in _mapsFromDocument(document)) {
      final pages = _mapValue(map, const ['pages', 'chapter_pages', 'images']);
      if (pages is List) {
        for (final page in pages) {
          if (page is Map) {
            result.add({
              for (final entry in page.entries) '${entry.key}': entry.value,
            });
          }
        }
      }
    }
    return result;
  }

  Object? _mapValue(Map<String, Object?> map, List<String> keys) {
    for (final key in keys) {
      for (final entry in map.entries) {
        if (entry.key.toLowerCase() == key.toLowerCase()) return entry.value;
      }
    }
    return null;
  }

  String? _stringValue(Map<String, Object?> map, List<String> keys) {
    final value = _mapValue(map, keys);
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is num || value is bool) return value.toString();
    return null;
  }

  String? _imageValue(Map<String, Object?> map, List<String> keys) {
    final value = _stringValue(map, keys);
    return value == null ? null : _pageImageUrl(value);
  }

  List<String> _stringListValue(Map<String, Object?> map, List<String> keys) {
    final value = _mapValue(map, keys);
    if (value is List) {
      return value
          .whereType<String>()
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .toList();
    }
    return value is String
        ? value
              .split(',')
              .map((v) => v.trim())
              .where((v) => v.isNotEmpty)
              .toList()
        : const [];
  }

  SourceMangaStatus? _statusFrom(String? value) {
    if (value == null) return null;
    if (value.contains('ongoing')) return SourceMangaStatus.ongoing;
    if (value.contains('complete') || value.contains('finished')) {
      return SourceMangaStatus.completed;
    }
    if (value.contains('hiatus')) return SourceMangaStatus.hiatus;
    if (value.contains('cancel') || value.contains('drop')) {
      return SourceMangaStatus.cancelled;
    }
    return null;
  }

  DateTime? _dateValue(Map<String, Object?> map) {
    final value = _stringValue(map, const [
      'updated_at',
      'published_at',
      'created_at',
      'date',
    ]);
    return value == null ? null : DateTime.tryParse(value);
  }

  String? _seriesSlug(String rawUrl) {
    final segments = _absUri(rawUrl).pathSegments;
    final comicIndex = segments.indexOf('comic');
    if (comicIndex >= 0 && comicIndex + 1 < segments.length) {
      return segments[comicIndex + 1];
    }
    return null;
  }

  String _chapterName(String rawUrl) {
    final segments = _absUri(rawUrl).pathSegments;
    final index = segments.indexOf('chapter');
    return index >= 0 && index + 1 < segments.length
        ? segments[index + 1]
        : 'Chapter';
  }

  String _pageImageUrl(String raw) => _normalizeImageUrl(_absUrl(raw));

  String _normalizeImageUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return raw;
    if (uri.scheme == 'http' &&
        (uri.host == 'sscdn.dbm.my.id' ||
            uri.host == 'img.soulscans.asia' ||
            uri.host.endsWith('.soulscans.asia'))) {
      return uri.replace(scheme: 'https').toString();
    }
    return raw;
  }
}
