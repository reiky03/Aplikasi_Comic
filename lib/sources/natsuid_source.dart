import 'dart:convert';
import 'dart:math';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../data/kizen_http_client.dart';
import '../data/source_session_store.dart';
import 'manga_source.dart';

/// Parser native untuk situs bertema WordPress "NatsuId" (dipakai Ikiru) —
/// diporting dari `lib-multisrc/natsuid` di `keiyoushi/extensions-source`.
///
/// Catatan: listing (popular/latest/search) memakai endpoint WP REST API
/// standar (`/wp-json/wp/v2/manga`) alih-alih endpoint AJAX pencarian
/// situs asli (yang butuh token "nonce" — nilai persis field
/// order/orderby AJAX-nya tidak bisa dipastikan tanpa akses situs
/// langsung). Detail komik, daftar chapter, dan daftar halaman (bagian
/// inti "baca komik") diporting 1:1 sesuai referensi.
class NatsuIdSource implements MangaSource {
  NatsuIdSource({
    required this.name,
    required this.baseUrl,
    http.Client? client,
    Iterable<String> fallbackBaseUrls = const [],
  })  : _client = client ?? createKizenHttpClient(),
        _fallbackBaseUrls = fallbackBaseUrls.toList() {
    _currentBaseUrl = baseUrl;
  }

  @override
  final String name;

  @override
  final String baseUrl;

  late String _currentBaseUrl;
  final List<String> _fallbackBaseUrls;
  final http.Client _client;
  final _random = Random();
  String? _searchNonce;

  String get currentBaseUrl => _currentBaseUrl;

  Map<String, String> get _headers => {
    'Referer': '$_currentBaseUrl/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    ...SourceSessionStore.headersFor(_currentBaseUrl),
  };

  Future<http.Response> _get(Uri url) async {
    try {
      final res = await _client.get(url, headers: _headers);
      if (res.statusCode == 403) {
        throw MangaSourceWebViewException(
          message:
              '$name terdeteksi Cloudflare Turnstile (403). Selesaikan verifikasi di WebView sekali agar sesi aktif.',
          url: url.toString(),
        );
      }
      return res;
    } catch (e) {
      if (e is MangaSourceWebViewException) rethrow;
      throw MangaSourceException('Gagal menghubungi $name: $e');
    }
  }

  Future<http.Response> _postMultipart(
    Uri url,
    Map<String, String> fields,
  ) async {
    final request = http.MultipartRequest('POST', url)
      ..headers.addAll(_headers)
      ..fields.addAll(fields);
    try {
      final res = await http.Response.fromStream(await _client.send(request));
      if (res.statusCode == 403) {
        throw MangaSourceWebViewException(
          message:
              '$name terdeteksi Cloudflare Turnstile (403). Selesaikan verifikasi di WebView sekali agar sesi aktif.',
          url: url.toString(),
        );
      }
      return res;
    } catch (e) {
      if (e is MangaSourceWebViewException) rethrow;
      throw MangaSourceException('Gagal menghubungi $name: $e');
    }
  }

  dynamic _decodeJsonResponse(String raw) {
    final objectStart = raw.indexOf('{');
    final arrayStart = raw.indexOf('[');
    final starts = [
      if (objectStart >= 0) objectStart,
      if (arrayStart >= 0) arrayStart,
    ];
    if (starts.isEmpty) throw const FormatException('Respons bukan JSON');
    starts.sort();
    return jsonDecode(raw.substring(starts.first));
  }

  Future<String> _getSearchNonce({bool refresh = false}) async {
    final cached = _searchNonce;
    if (!refresh && cached != null) return cached;

    final candidates = <String>[
      _currentBaseUrl,
      ..._fallbackBaseUrls.where((b) => b != _currentBaseUrl),
    ];

    Object? lastError;
    for (final candidate in candidates) {
      try {
        final url = Uri.parse(
          '$candidate/wp-admin/admin-ajax.php',
        ).replace(queryParameters: {'type': 'search_form', 'action': 'get_nonce'});
        final response = await _client.get(url, headers: {
          'Referer': '$candidate/',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          ...SourceSessionStore.headersFor(candidate),
        });
        if (response.statusCode == 403) {
          throw MangaSourceWebViewException(
            message:
                '$name terdeteksi Cloudflare Turnstile (403). Selesaikan verifikasi di WebView sekali agar sesi aktif.',
            url: candidate,
          );
        }
        if (response.statusCode != 200) continue;
        final nonce = html_parser
            .parseFragment(response.body)
            .querySelector('input[name="search_nonce"]')
            ?.attributes['value']
            ?.trim();
        if (nonce != null && nonce.isNotEmpty) {
          _currentBaseUrl = candidate;
          _searchNonce = nonce;
          return nonce;
        }
      } catch (e) {
        lastError = e;
        if (e is MangaSourceWebViewException) rethrow;
      }
    }

    if (lastError is MangaSourceWebViewException) throw lastError;
    throw MangaSourceException('Token pencarian $name tidak ditemukan.');
  }

  Future<SourceMangaPage> _advancedList({
    required int page,
    required String orderBy,
    String query = '',
    bool retryNonce = true,
  }) async {
    final nonce = await _getSearchNonce();
    final url = Uri.parse(
      '$_currentBaseUrl/wp-admin/admin-ajax.php',
    ).replace(queryParameters: {'action': 'advanced_search'});
    final response = await _postMultipart(url, {
      'nonce': nonce,
      'inclusion': 'OR',
      'exclusion': 'OR',
      'page': '$page',
      'genre': '[]',
      'genre_exclude': '[]',
      'author': '[]',
      'artist': '[]',
      'project': '0',
      'type': '[]',
      'status': '[]',
      'order': 'desc',
      'orderby': orderBy,
      'query': query.trim(),
    });
    if (response.statusCode != 200) {
      if (retryNonce &&
          (response.statusCode == 400 ||
              response.statusCode == 401 ||
              response.statusCode == 403)) {
        _searchNonce = null;
        await _getSearchNonce(refresh: true);
        return _advancedList(
          page: page,
          orderBy: orderBy,
          query: query,
          retryNonce: false,
        );
      }
      throw MangaSourceException(
        '$name mengembalikan status ${response.statusCode}.',
      );
    }

    final fragment = html_parser.parseFragment(response.body);
    final slugs = <String>[];
    final seen = <String>{};
    for (final anchor in fragment.querySelectorAll(
      'div > a[href*="/manga/"]',
    )) {
      if (anchor.querySelector('img') == null) continue;
      final href = anchor.attributes['href'];
      if (href == null || href.isEmpty) continue;
      final segments = Uri.parse(_currentBaseUrl)
          .resolve(href)
          .pathSegments
          .where((segment) => segment.isNotEmpty)
          .toList();
      final mangaIndex = segments.indexWhere(
        (segment) => segment.toLowerCase() == 'manga',
      );
      if (mangaIndex < 0 || mangaIndex + 1 >= segments.length) continue;
      final slug = segments[mangaIndex + 1];
      if (seen.add(slug)) slugs.add(slug);
    }
    if (slugs.isEmpty) {
      throw MangaSourceException('Daftar pencarian $name kosong.');
    }

    final detailsUrl = Uri.parse('$_currentBaseUrl/wp-json/wp/v2/manga').replace(
      queryParameters: {
        'slug[]': slugs,
        'per_page': '${slugs.length + 1}',
        '_embed': '',
      },
    );
    final detailsResponse = await _get(detailsUrl);
    if (detailsResponse.statusCode != 200) {
      throw MangaSourceException(
        '$name mengembalikan status ${detailsResponse.statusCode}.',
      );
    }
    final decoded = _decodeJsonResponse(detailsResponse.body);
    if (decoded is! List) {
      throw MangaSourceException('Data katalog $name tidak valid.');
    }
    final bySlug = <String, SourceManga>{};
    for (final raw in decoded.whereType<Map>()) {
      final json = Map<String, dynamic>.from(raw);
      final embedded = json['_embedded'] as Map<String, dynamic>? ?? {};
      final types = _termsOf(embedded, 'type');
      if (types.any((type) => type.toLowerCase() == 'novel')) continue;
      final manga = _mangaFromJson(json);
      final slug = json['slug'] as String?;
      if (slug != null && manga.title.isNotEmpty) bySlug[slug] = manga;
    }
    final mangas = [for (final slug in slugs) ?bySlug[slug]];
    if (mangas.isEmpty) {
      throw MangaSourceException('Detail katalog $name kosong.');
    }
    final hasNextPage = fragment
        .querySelectorAll('button')
        .any((button) => button.querySelector('svg') != null);
    return SourceMangaPage(mangas: mangas, hasNextPage: hasNextPage);
  }

  Future<SourceMangaPage> _legacyList({
    required int page,
    String? search,
    bool latest = false,
  }) async {
    final url = Uri.parse('$_currentBaseUrl/wp-json/wp/v2/manga').replace(
      queryParameters: {
        'page': '$page',
        'per_page': '20',
        '_embed': '',
        if (search != null && search.isNotEmpty) 'search': search,
        if (latest) 'orderby': 'modified',
        if (latest) 'order': 'desc',
      },
    );
    final response = await _get(url);
    if (response.statusCode != 200) {
      throw MangaSourceException(
        '$name mengembalikan status ${response.statusCode}.',
      );
    }
    final decoded = _decodeJsonResponse(response.body);
    if (decoded is! List) {
      throw MangaSourceException('Data katalog $name tidak valid.');
    }
    final list = decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final mangas = list.map(_mangaFromJson).toList();
    final totalPagesHeader = response.headers['x-wp-totalpages'];
    final totalPages = int.tryParse(totalPagesHeader ?? '') ?? (page + 1);
    return SourceMangaPage(mangas: mangas, hasNextPage: page < totalPages);
  }

  SourceManga _mangaFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final slug = json['slug'] as String? ?? '';
    final renderedTitle =
        (json['title'] as Map<String, dynamic>?)?['rendered'] as String? ?? '';
    final title = html_parser.parseFragment(renderedTitle).text?.trim() ?? '';
    final embedded = json['_embedded'] as Map<String, dynamic>? ?? {};
    final media = (embedded['wp:featuredmedia'] as List<dynamic>? ?? [])
        .cast<Map>();
    final thumbnail = media.isEmpty
        ? null
        : media.first['source_url'] as String?;
    return SourceManga(
      url: jsonEncode({'id': id, 'slug': slug}),
      title: title,
      thumbnailUrl: thumbnail,
    );
  }

  Future<SourceMangaPage> _htmlList({
    required int page,
    bool latest = false,
  }) async {
    final path = latest
        ? (page <= 1 ? '/' : '/manga/?page=$page&order=update')
        : (page <= 1 ? '/manga/' : '/manga/?page=$page');
    final url = Uri.parse('$_currentBaseUrl$path');
    final response = await _get(url);
    if (response.statusCode != 200) {
      throw MangaSourceException('$name mengembalikan status ${response.statusCode}.');
    }
    final fragment = html_parser.parse(response.body);
    final mangas = <SourceManga>[];
    final seen = <String>{};

    for (final anchor in fragment.querySelectorAll('div.bsx > a, div.listupd a[href*="/manga/"]')) {
      final href = anchor.attributes['href'];
      if (href == null ||
          href.isEmpty ||
          href.contains('/chapter/') ||
          href.contains('/chapter-') ||
          href.contains('/ch-')) {
        continue;
      }
      final segments = Uri.tryParse(href)?.pathSegments.where((s) => s.isNotEmpty).toList() ?? [];
      final mIdx = segments.indexOf('manga');
      if (mIdx >= 0 && segments.length > mIdx + 2) continue;

      final fullUrl = Uri.parse(_currentBaseUrl).resolve(href).toString();
      if (!seen.add(fullUrl)) continue;

      final title = anchor.attributes['title']?.trim() ??
          anchor.querySelector('.tt, h4, .title')?.text.trim() ??
          anchor.text.trim();
      if (title.isEmpty ||
          title.toLowerCase().startsWith('ch.') ||
          title.toLowerCase().startsWith('ch ') ||
          title.toLowerCase().contains('chapter')) {
        continue;
      }

      final img = anchor.querySelector('img');
      final cover = img?.attributes['data-src'] ??
          img?.attributes['data-lazy-src'] ??
          img?.attributes['src'];
      if (img == null && cover == null) continue;

      mangas.add(
        SourceManga(
          url: fullUrl,
          title: title,
          thumbnailUrl: cover,
          headers: _headers,
        ),
      );
    }
    if (mangas.isEmpty) {
      throw MangaSourceException('Katalog HTML $name kosong.');
    }
    return SourceMangaPage(mangas: mangas, hasNextPage: mangas.length >= 10);
  }

  Future<SourceMangaPage> _nuxtHomeList({required bool latest}) async {
    final response = await _get(Uri.parse('$_currentBaseUrl/'));
    if (response.statusCode != 200) {
      throw MangaSourceException('$name mengembalikan status ${response.statusCode}.');
    }
    final doc = html_parser.parse(response.body);
    final mangas = <SourceManga>[];
    final seen = <String>{};

    if (!latest) {
      // 1. Hero / Carousel
      for (final slide in doc.querySelectorAll(
        '.slide-in, .hero-carousel [class*="slide"], .hero-cta',
      )) {
        final title = slide.querySelector('h1')?.text.trim();
        final a = slide.querySelector('a[href^="/manga/"]:not([href*="/chapter"])');
        final img = slide.querySelector('img');
        final href = a?.attributes['href'];
        final cover = img?.attributes['src'] ?? img?.attributes['data-src'];
        if (title != null && title.isNotEmpty && href != null) {
          final fullUrl = Uri.parse(_currentBaseUrl).resolve(href).toString();
          if (seen.add(fullUrl)) {
            final fullCover = cover == null || cover.isEmpty
                ? null
                : Uri.parse(_currentBaseUrl).resolve(cover).toString();
            mangas.add(SourceManga(
              url: fullUrl,
              title: title,
              thumbnailUrl: fullCover,
              headers: _headers,
            ));
          }
        }
      }

      // 2. Rekomendasi & Popular Cards
      for (final card in doc.querySelectorAll('.card, div[class*="card"]')) {
        final aCover = card.querySelector('a.cover');
        if (aCover == null) continue;
        final href = aCover.attributes['href'];
        if (href == null || href.isEmpty || href.contains('/chapter')) continue;
        var title = aCover.attributes['aria-label']?.trim() ??
            aCover.querySelector('.ctitle')?.text.trim() ??
            '';
        if (title.toLowerCase().startsWith('lihat detail ')) {
          title = title.substring(13).trim();
        }
        if (title.isEmpty) continue;
        final img = aCover.querySelector('img');
        final cover = img?.attributes['src'] ?? img?.attributes['data-src'];
        final fullUrl = Uri.parse(_currentBaseUrl).resolve(href).toString();
        if (seen.add(fullUrl)) {
          final fullCover = cover == null || cover.isEmpty
              ? null
              : Uri.parse(_currentBaseUrl).resolve(cover).toString();
          mangas.add(SourceManga(
            url: fullUrl,
            title: title,
            thumbnailUrl: fullCover,
            headers: _headers,
          ));
        }
      }
    } else {
      // Latest: Cards with .chaps or .chap
      for (final card in doc.querySelectorAll('.card, div[class*="card"]')) {
        final aCover = card.querySelector('a.cover');
        if (aCover == null) continue;
        final href = aCover.attributes['href'];
        if (href == null || href.isEmpty || href.contains('/chapter')) continue;
        var title = aCover.attributes['aria-label']?.trim() ??
            aCover.querySelector('.ctitle')?.text.trim() ??
            '';
        if (title.toLowerCase().startsWith('lihat detail ')) {
          title = title.substring(13).trim();
        }
        if (title.isEmpty) continue;
        final hasChaps = card.querySelector('.chaps, .chap') != null;
        if (!hasChaps) continue;
        final img = aCover.querySelector('img');
        final cover = img?.attributes['src'] ?? img?.attributes['data-src'];
        final fullUrl = Uri.parse(_currentBaseUrl).resolve(href).toString();
        if (seen.add(fullUrl)) {
          final fullCover = cover == null || cover.isEmpty
              ? null
              : Uri.parse(_currentBaseUrl).resolve(cover).toString();
          mangas.add(SourceManga(
            url: fullUrl,
            title: title,
            thumbnailUrl: fullCover,
            headers: _headers,
          ));
        }
      }
    }

    if (mangas.isEmpty) {
      throw MangaSourceException('Daftar Nuxt $name kosong.');
    }
    return SourceMangaPage(mangas: mangas, hasNextPage: false);
  }

  Future<SourceMangaDetails> _nuxtDetails(String mangaUrl) async {
    final response = await _get(Uri.parse(mangaUrl));
    if (response.statusCode != 200) {
      throw MangaSourceException('$name mengembalikan status ${response.statusCode}.');
    }
    final doc = html_parser.parse(response.body);
    final script = doc.querySelector('script#__NUXT_DATA__');
    if (script == null) {
      throw MangaSourceException('__NUXT_DATA__ tidak ditemukan di $name.');
    }
    final raw = jsonDecode(script.text.trim()) as List<dynamic>;
    String? description;
    String? author;
    String? artist;
    final genres = <String>[];
    var status = SourceMangaStatus.unknown;

    for (final item in raw) {
      if (item is Map) {
        if (item.containsKey('description') &&
            item.containsKey('title') &&
            item.containsKey('chapters')) {
          final descVal = item['description'];
          if (descVal is int && descVal < raw.length && raw[descVal] is String) {
            description = html_parser
                .parse(raw[descVal] as String)
                .body
                ?.text
                .trim();
          }
          final statusVal = item['status'];
          final statusStr = statusVal is int &&
                  statusVal < raw.length &&
                  raw[statusVal] is String
              ? (raw[statusVal] as String).toLowerCase()
              : (statusVal is String ? statusVal.toLowerCase() : '');
          if (statusStr.contains('ongoing')) {
            status = SourceMangaStatus.ongoing;
          } else if (statusStr.contains('completed') ||
              statusStr.contains('tamat')) {
            status = SourceMangaStatus.completed;
          }
        }
      }
    }

    for (final tag in doc.querySelectorAll(
      'a[href*="/genre/"], .genres a, .genre a',
    )) {
      final g = tag.text.trim();
      if (g.isNotEmpty && !genres.contains(g)) genres.add(g);
    }

    return SourceMangaDetails(
      description: description ??
          doc.querySelector('.description, .desc, p')?.text.trim(),
      author: author,
      artist: artist,
      genres: genres,
      status: status,
    );
  }

  Future<List<SourceChapter>> _nuxtChapters(String mangaUrl) async {
    final response = await _get(Uri.parse(mangaUrl));
    if (response.statusCode != 200) {
      throw MangaSourceException('$name mengembalikan status ${response.statusCode}.');
    }
    final doc = html_parser.parse(response.body);
    final script = doc.querySelector('script#__NUXT_DATA__');
    if (script == null) {
      throw MangaSourceException('__NUXT_DATA__ tidak ditemukan di $name.');
    }
    final raw = jsonDecode(script.text.trim()) as List<dynamic>;
    final chapters = <SourceChapter>[];

    for (final item in raw) {
      if (item is Map &&
          item.containsKey('chapters') &&
          item['chapters'] is int) {
        final listIdx = item['chapters'] as int;
        if (listIdx < raw.length && raw[listIdx] is List) {
          for (final chapIdx in raw[listIdx] as List) {
            if (chapIdx is int && chapIdx < raw.length && raw[chapIdx] is Map) {
              final chapMap = raw[chapIdx] as Map;
              final numVal = chapMap['number'];
              final resolvedNum = numVal is int && numVal < raw.length
                  ? raw[numVal]
                  : numVal;
              final titleVal = chapMap['title'];
              final resolvedTitle = titleVal is int &&
                      titleVal < raw.length &&
                      raw[titleVal] is String
                  ? raw[titleVal] as String
                  : (titleVal is String ? titleVal : 'Chapter $resolvedNum');
              final dateVal = chapMap['createdAt'];
              final dateStr = dateVal is int &&
                      dateVal < raw.length &&
                      raw[dateVal] is String
                  ? raw[dateVal] as String
                  : (dateVal is String ? dateVal : null);

              final cleanMangaUrl = mangaUrl.endsWith('/')
                  ? mangaUrl.substring(0, mangaUrl.length - 1)
                  : mangaUrl;
              final chapUrl = '$cleanMangaUrl/chapter-$resolvedNum';

              chapters.add(
                SourceChapter(
                  url: chapUrl,
                  name: resolvedTitle,
                  dateUpload: dateStr != null
                      ? DateTime.tryParse(dateStr)
                      : null,
                ),
              );
            }
          }
        }
      }
    }

    if (chapters.isEmpty) {
      for (final a in doc.querySelectorAll(
        'a[href*="/chapter"], a.chap, div.chaps a',
      )) {
        final href = a.attributes['href'];
        if (href == null || href.isEmpty) continue;
        final name = a.querySelector('.cn')?.text.trim() ?? a.text.trim();
        chapters.add(
          SourceChapter(
            url: Uri.parse(_currentBaseUrl).resolve(href).toString(),
            name: name,
          ),
        );
      }
    }

    if (chapters.isEmpty) {
      throw MangaSourceException('Daftar chapter Nuxt $name kosong.');
    }
    return chapters;
  }

  Future<List<SourcePage>> _nuxtPages(String chapterUrl) async {
    final response = await _get(Uri.parse(chapterUrl));
    if (response.statusCode != 200) {
      throw MangaSourceException('$name mengembalikan status ${response.statusCode}.');
    }
    final doc = html_parser.parse(response.body);
    final pages = <SourcePage>[];
    final seen = <String>{};

    final script = doc.querySelector('script#__NUXT_DATA__');
    if (script != null) {
      try {
        final raw = jsonDecode(script.text.trim()) as List<dynamic>;
        for (final item in raw) {
          if (item is String) {
            final lower = item.toLowerCase();
            if ((lower.endsWith('.webp') ||
                    lower.endsWith('.jpg') ||
                    lower.endsWith('.jpeg') ||
                    lower.endsWith('.png')) &&
                (lower.contains('cdn.ikiru') ||
                    lower.contains('/t/') ||
                    lower.contains('/c/') ||
                    lower.contains('/featured/'))) {
              if (lower.contains('cover') ||
                  lower.contains('logo') ||
                  lower.contains('avatar') ||
                  lower.contains('icon')) {
                continue;
              }
              final fullUrl =
                  Uri.parse(_currentBaseUrl).resolve(item).toString();
              if (seen.add(fullUrl)) {
                pages.add(SourcePage(index: pages.length, imageUrl: fullUrl));
              }
            }
          }
        }
      } catch (_) {}
    }

    for (final img in doc.querySelectorAll(
      'main img, .chapter-content img, .reader-area img, div[class*="reader"] img, img',
    )) {
      final src = img.attributes['src'] ?? img.attributes['data-src'];
      if (src == null || src.isEmpty) continue;
      final lower = src.toLowerCase();
      if (lower.contains('cover') ||
          lower.contains('logo') ||
          lower.contains('avatar') ||
          lower.contains('icon')) {
        continue;
      }
      if (lower.contains('cdn.ikiru') ||
          lower.contains('/t/') ||
          lower.contains('/c/')) {
        final fullUrl = Uri.parse(_currentBaseUrl).resolve(src).toString();
        if (seen.add(fullUrl)) {
          pages.add(SourcePage(index: pages.length, imageUrl: fullUrl));
        }
      }
    }

    if (pages.isEmpty) {
      throw MangaSourceException('Halaman baca Nuxt $name kosong.');
    }
    return pages;
  }

  @override
  Future<SourceMangaPage> fetchPopular(int page) async {
    try {
      return await _nuxtHomeList(latest: false);
    } catch (_) {
      try {
        return await _advancedList(page: page, orderBy: 'popular');
      } catch (_) {
        try {
          return await _legacyList(page: page);
        } catch (_) {
          return _htmlList(page: page, latest: false);
        }
      }
    }
  }

  @override
  Future<SourceMangaPage> fetchLatest(int page) async {
    try {
      return await _nuxtHomeList(latest: true);
    } catch (_) {
      try {
        return await _advancedList(page: page, orderBy: 'update');
      } catch (_) {
        try {
          return await _legacyList(page: page, latest: true);
        } catch (_) {
          return _htmlList(page: page, latest: true);
        }
      }
    }
  }

  @override
  Future<SourceMangaPage> fetchSearch(String query, int page) async {
    try {
      final home = await _nuxtHomeList(latest: false);
      final q = query.toLowerCase().trim();
      final filtered = home.mangas
          .where((m) => m.title.toLowerCase().contains(q))
          .toList();
      if (filtered.isNotEmpty) {
        return SourceMangaPage(mangas: filtered, hasNextPage: false);
      }
    } catch (_) {}

    try {
      return await _advancedList(page: page, orderBy: 'popular', query: query);
    } catch (_) {
      return _legacyList(page: page, search: query);
    }
  }

  int _mangaId(String mangaUrl) {
    try {
      final decoded = jsonDecode(mangaUrl);
      if (decoded is Map && decoded.containsKey('id')) {
        return (decoded['id'] as num).toInt();
      }
    } catch (_) {}
    final m = RegExp(r'/(\d+)/?$').firstMatch(mangaUrl);
    if (m != null) return int.tryParse(m.group(1)!) ?? -1;
    return -1;
  }

  List<String> _termsOf(Map<String, dynamic> embedded, String taxonomy) {
    final termGroups = (embedded['wp:term'] as List<dynamic>? ?? [])
        .cast<List<dynamic>>();
    for (final group in termGroups) {
      final items = group.cast<Map<String, dynamic>>();
      if (items.isNotEmpty && items.first['taxonomy'] == taxonomy) {
        return items.map((t) => t['name'] as String? ?? '').toList();
      }
    }
    return const [];
  }

  @override
  Future<SourceMangaDetails> fetchMangaDetails(String mangaUrl) async {
    try {
      return await _nuxtDetails(mangaUrl);
    } catch (_) {}

    final id = _mangaId(mangaUrl);
    final url = Uri.parse(
      '$baseUrl/wp-json/wp/v2/manga/$id',
    ).replace(queryParameters: {'_embed': ''});
    final response = await _get(url);
    if (response.statusCode != 200) {
      throw MangaSourceException(
        '$name mengembalikan status ${response.statusCode}.',
      );
    }
    final json = Map<String, dynamic>.from(
      _decodeJsonResponse(response.body) as Map,
    );
    final embedded = json['_embedded'] as Map<String, dynamic>? ?? {};
    final content =
        (json['content'] as Map<String, dynamic>?)?['rendered'] as String?;
    final description = content == null
        ? null
        : html_parser.parse(content).body?.text.trim();

    final status = _termsOf(embedded, 'status');
    return SourceMangaDetails(
      description: description,
      author: _termsOf(embedded, 'series-author').join(', ').ifEmptyNull(),
      artist: _termsOf(embedded, 'artist').join(', ').ifEmptyNull(),
      genres: [..._termsOf(embedded, 'genre'), ..._termsOf(embedded, 'type')],
      status: switch (status) {
        [final s, ...] when s == 'Ongoing' => SourceMangaStatus.ongoing,
        [final s, ...] when s == 'Completed' => SourceMangaStatus.completed,
        [final s, ...] when s == 'Cancelled' => SourceMangaStatus.cancelled,
        [final s, ...] when s == 'On Hiatus' => SourceMangaStatus.hiatus,
        _ => SourceMangaStatus.unknown,
      },
    );
  }

  @override
  Future<List<SourceChapter>> fetchChapterList(String mangaUrl) async {
    try {
      return await _nuxtChapters(mangaUrl);
    } catch (_) {}

    final id = _mangaId(mangaUrl);
    final url = Uri.parse('$baseUrl/wp-admin/admin-ajax.php').replace(
      queryParameters: {
        'manga_id': '$id',
        'page': '${99 + _random.nextInt(9900)}',
        'action': 'chapter_list',
      },
    );
    final response = await _get(url);
    if (response.statusCode != 200) {
      throw MangaSourceException(
        '$name mengembalikan status ${response.statusCode}.',
      );
    }
    final fragment = html_parser.parseFragment(response.body);
    final chapters = <SourceChapter>[];
    for (final a in fragment.querySelectorAll('div a')) {
      final time = a.querySelector('time');
      if (time == null) continue;
      final span = a.querySelector('span');
      chapters.add(
        SourceChapter(
          url: Uri.parse(
            baseUrl,
          ).resolve(a.attributes['href'] ?? '').toString(),
          name: span?.text.trim() ?? '',
          dateUpload: DateTime.tryParse(time.attributes['datetime'] ?? ''),
        ),
      );
    }
    return chapters;
  }

  @override
  Future<List<SourcePage>> fetchPageList(String chapterUrl) async {
    try {
      return await _nuxtPages(chapterUrl);
    } catch (_) {}

    final response = await _get(Uri.parse(chapterUrl));
    if (response.statusCode != 200) {
      throw MangaSourceException(
        '$name mengembalikan status ${response.statusCode}.',
      );
    }
    final document = html_parser.parse(response.body);
    final imgs = document.querySelectorAll('main .relative section > img');
    return [
      for (var i = 0; i < imgs.length; i++)
        SourcePage(
          index: i,
          imageUrl: Uri.parse(
            baseUrl,
          ).resolve(imgs[i].attributes['src'] ?? '').toString(),
        ),
    ];
  }
}

extension _StringExt on String {
  String? ifEmptyNull() => isEmpty ? null : this;
}
