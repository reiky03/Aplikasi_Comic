import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../data/extension_runtime.dart';
import '../data/source_session_store.dart';
import 'manga_source.dart';
import 'sveltekit_comic_source.dart';

/// Parser fallback generik untuk situs komik HTML biasa.
///
/// Ini sengaja bukan parser per-domain: dia mencoba banyak selector umum
/// yang dipakai theme manga/WordPress/Tachiyomi-like. Situs yang butuh
/// JavaScript browser, Cloudflare challenge, login, atau API khusus tetap
/// perlu WebView/native parser.
class UniversalHtmlSource implements MangaSource {
  UniversalHtmlSource({
    required this.name,
    required this.baseUrl,
    http.Client? client,
    ExtensionRuntimeBridge? bridge,
    this.enableBrowserSessionFallback = false,
  }) : _client = client ?? http.Client(),
       _bridge = bridge ?? const ExtensionRuntimeBridge(),
       _svelteKitFallback = SvelteKitComicSource(
         name: name,
         baseUrl: baseUrl,
         client: client,
       );

  @override
  final String name;

  @override
  final String baseUrl;

  /// Hanya diaktifkan oleh source yang memang perlu browser session.
  /// Default false supaya parser source lain tidak memicu WebView tersembunyi.
  final bool enableBrowserSessionFallback;

  final http.Client _client;
  final ExtensionRuntimeBridge _bridge;
  final SvelteKitComicSource _svelteKitFallback;

  bool get _isToongod {
    final host = Uri.tryParse(baseUrl)?.host.toLowerCase();
    return host == 'toongod.org' || host?.endsWith('.toongod.org') == true;
  }

  // Mode aman dulu: WebView render otomatis pernah bikin ANR di device asli
  // ketika dipanggil dari parser universal. WebView manual tetap lewat UI.
  static const _maxEmbeddedJsonScriptLength = 180000;
  static const _maxInlineJsonScriptLength = 220000;
  static const _maxRawImageScanLength = 450000;

  Map<String, String> get _headers => {
    'Referer': '$baseUrl/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    ...SourceSessionStore.headersFor(baseUrl),
  };

  Uri _absUri(Uri uri) => Uri.parse(baseUrl).resolveUri(uri);

  Future<Document> _getHtml(Uri url) async {
    final requestUrl = _absUri(url);
    late final http.Response response;
    try {
      response = await _client
          .get(requestUrl, headers: _headers)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      final rendered = await _getRenderedHtml(requestUrl);
      if (rendered != null) return rendered;
      throw MangaSourceException('Gagal menghubungi $name: $e');
    }
    if (response.statusCode != 200) {
      if (_shouldTryRenderedHtml(response.statusCode)) {
        final rendered = await _getRenderedHtml(requestUrl);
        if (rendered != null) return rendered;
      }
      throw MangaSourceException(
        '$name mengembalikan status ${response.statusCode}.',
      );
    }
    final lower = response.body.toLowerCase();
    if (lower.contains('sedang maintenance') ||
        lower.contains('peningkatan server') ||
        lower.contains('under maintenance')) {
      throw MangaSourceException('$name sedang maintenance dari sisi website.');
    }
    if (lower.contains('/cdn-cgi/challenge-platform/') ||
        lower.contains('just a moment') ||
        lower.contains('error establishing a redis connection')) {
      final rendered = await _getRenderedHtml(requestUrl);
      if (rendered != null) return rendered;
      throw MangaSourceException(
        '$name butuh sesi browser. Buka lewat WebView dulu.',
      );
    }
    return html_parser.parse(response.body);
  }

  Future<Document?> _getRenderedHtml(Uri url) async {
    if (!enableBrowserSessionFallback) return null;
    final requestUrl = _absUri(url);
    try {
      final html = await _bridge
          .renderHtmlWithWebView(
            requestUrl.toString(),
            sessionHeaders: {
              ...SourceSessionStore.headersFor(baseUrl),
              ...SourceSessionStore.headersFor(requestUrl.toString()),
            },
          )
          .timeout(const Duration(seconds: 20));
      if (html.trim().length < 80) return null;
      return html_parser.parse(html);
    } catch (_) {
      return null;
    }
  }

  Future<http.Response> _getJson(Uri url) => _client
      .get(_absUri(url), headers: {..._headers, 'Accept': 'application/json'})
      .timeout(const Duration(seconds: 15));

  String _absUrl(String href) =>
      _normalizeImageUrl(Uri.parse(baseUrl).resolve(href).toString());

  String _normalizeImageUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return raw;
    if (_isToongod &&
        (uri.host == 'toongod.org' || uri.host.endsWith('.toongod.org')) &&
        uri.path.startsWith('/wp-content/uploads/')) {
      return Uri(
        scheme: 'https',
        host: 'i0.wp.com',
        path: '/${uri.host}${uri.path}',
        query: uri.hasQuery ? uri.query : null,
      ).toString();
    }
    if (uri.scheme == 'http' &&
        (uri.host == 'sscdn.dbm.my.id' ||
            uri.host == 'img.soulscans.asia' ||
            uri.host.endsWith('.soulscans.asia'))) {
      return uri.replace(scheme: 'https').toString();
    }
    return raw;
  }

  Map<String, String> _headersForAsset(String? url) {
    final host = Uri.tryParse(url ?? '')?.host.toLowerCase();
    // Cookie clearance Toongod tidak boleh ikut bocor ke CDN WordPress.
    // i0.wp.com bersifat publik dan justru gagal kalau menerima header sesi
    // lintas-domain yang tidak cocok.
    if (host == 'i0.wp.com') return const {};
    return _headers;
  }

  Uri _apiBase(Uri base) {
    final host = base.host.startsWith('api.') ? base.host : 'api.${base.host}';
    return base.replace(host: host, path: '/', query: null, fragment: null);
  }

  String? _slugFromUrl(String rawUrl) {
    final uri = Uri.tryParse(_absUrl(rawUrl));
    if (uri == null || uri.pathSegments.isEmpty) return null;
    const ignored = {
      'manga',
      'comic',
      'comics',
      'komik',
      'series',
      'webtoon',
      'title',
      'titles',
      'chapter',
      'episode',
      'eps',
    };
    for (final segment in uri.pathSegments.reversed) {
      final clean = segment.trim();
      if (clean.isEmpty || ignored.contains(clean.toLowerCase())) continue;
      return clean;
    }
    return null;
  }

  String _decodeEmbeddedUrl(String value) => value
      .trim()
      .replaceAll(r'\\/', '/')
      .replaceAll(r'\/', '/')
      .replaceAll(r'\u002F', '/')
      .replaceAll(r'\u002f', '/')
      .replaceAll('&amp;', '&');

  String? _imgAttr(Element img) {
    for (final attr in [
      'data-lazy-src',
      'data-src',
      'data-cfsrc',
      'data-original',
      'data-url',
      'data-lazy',
      'data-image',
      'data-thumb',
      'data-background-image',
      'srcset',
      'src',
    ]) {
      var value = img.attributes[attr];
      if (value == null) continue;
      if (attr == 'srcset') {
        value = value.split(',').first.trim().split(' ').first;
      }
      value = _decodeEmbeddedUrl(value);
      if (_isRealImageUrl(value)) return _absUrl(value);
    }
    final style = img.attributes['style'];
    final background = style == null
        ? null
        : RegExp(r'''url\(["']?([^"')]+)''').firstMatch(style)?.group(1);
    if (_isRealImageUrl(background)) {
      return _absUrl(_decodeEmbeddedUrl(background!));
    }
    return null;
  }

  bool _isRealImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final lower = _decodeEmbeddedUrl(url).toLowerCase();
    if (lower.startsWith('data:')) return false;
    if (lower.contains('placeholder') ||
        lower.contains('loading.') ||
        lower.contains('blank.') ||
        lower.contains('/logo') ||
        lower.contains('/icon') ||
        lower.contains('/avatar') ||
        lower.contains('/ads')) {
      return false;
    }
    if (lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.webp') ||
        lower.contains('.avif') ||
        lower.contains('%2ejpg') ||
        lower.contains('%2epng') ||
        lower.contains('%2ewebp')) {
      return true;
    }
    final uri = Uri.tryParse(lower);
    if (uri == null) return false;
    final value = '${uri.host}${uri.path}${uri.query}';
    return value.contains('/image') ||
        value.contains('/img/') ||
        value.contains('/uploads/') ||
        value.contains('/covers/') ||
        value.contains('/thumbnails/') ||
        value.contains('image_url=') ||
        value.contains('imageurl=');
  }

  @override
  Future<SourceMangaPage> fetchPopular(int page) async {
    try {
      return await _list(page: page);
    } catch (error) {
      try {
        final alternative = await _svelteKitFallback.fetchPopular(page);
        if (alternative.mangas.isNotEmpty) return alternative;
      } catch (_) {
        // Parser SvelteKit juga tidak cocok; kembalikan error utama.
      }
      Error.throwWithStackTrace(error, StackTrace.current);
    }
  }

  @override
  Future<SourceMangaPage> fetchLatest(int page) async {
    try {
      return await _list(page: page, order: 'update');
    } catch (error) {
      try {
        final alternative = await _svelteKitFallback.fetchLatest(page);
        if (alternative.mangas.isNotEmpty) return alternative;
      } catch (_) {
        // Parser SvelteKit juga tidak cocok; kembalikan error utama.
      }
      Error.throwWithStackTrace(error, StackTrace.current);
    }
  }

  @override
  Future<SourceMangaPage> fetchSearch(String query, int page) async {
    try {
      return await _list(page: page, query: query);
    } catch (error) {
      try {
        final alternative = await _svelteKitFallback.fetchSearch(query, page);
        if (alternative.mangas.isNotEmpty) return alternative;
      } catch (_) {
        // Parser SvelteKit juga tidak cocok; kembalikan error utama.
      }
      Error.throwWithStackTrace(error, StackTrace.current);
    }
  }

  Future<SourceMangaPage> _list({
    required int page,
    String query = '',
    String order = 'popular',
  }) async {
    final urls = _listingCandidates(page: page, query: query, order: order);
    Object? lastError;
    for (var i = 0; i < urls.length; i++) {
      final url = urls[i];
      try {
        final document = await _getHtml(url);
        final mangas = _parseMangaCards(document);
        if (mangas.isNotEmpty) {
          // Beberapa homepage SvelteKit memang valid, tapi hanya mengirim
          // section ringkas (Soulscans misalnya 4 komik). Cek katalog penuh
          // sebelum menganggap hasil kecil ini sudah final.
          if (mangas.length < 20 && _looksLikeSvelteKitDocument(document)) {
            try {
              final alternative = query.trim().isNotEmpty
                  ? await _svelteKitFallback.fetchSearch(query, page)
                  : order == 'update'
                  ? await _svelteKitFallback.fetchLatest(page)
                  : await _svelteKitFallback.fetchPopular(page);
              if (alternative.mangas.length > mangas.length) return alternative;
            } catch (_) {
              // Katalog SvelteKit tidak tersedia; pakai hasil HTML yang ada.
            }
          }
          return SourceMangaPage(
            mangas: mangas,
            hasNextPage: _hasNextPage(document),
          );
        }
        if (i == 0 || _looksLikeJsShell(document)) {
          final rendered = await _getRenderedHtml(url);
          if (rendered != null) {
            final renderedMangas = _parseMangaCards(rendered);
            if (renderedMangas.isNotEmpty) {
              return SourceMangaPage(
                mangas: renderedMangas,
                hasNextPage: _hasNextPage(rendered),
              );
            }
          }
        }
      } catch (e) {
        lastError = e;
      }
    }
    final apiPage = await _listFromApi(page: page, query: query, order: order);
    if (apiPage != null) return apiPage;
    throw MangaSourceException(
      'Struktur daftar komik $name belum dikenali'
      '${lastError == null ? '' : ': $lastError'}',
    );
  }

  bool _shouldTryRenderedHtml(int statusCode) =>
      statusCode == 403 ||
      statusCode == 408 ||
      statusCode == 409 ||
      statusCode == 418 ||
      statusCode == 429 ||
      statusCode == 500 ||
      statusCode == 502 ||
      statusCode == 503 ||
      statusCode == 520 ||
      statusCode == 521 ||
      statusCode == 522 ||
      statusCode == 523 ||
      statusCode == 524;

  bool _looksLikeJsShell(Document document) {
    final raw = document.outerHtml.toLowerCase();
    return raw.contains('id="app"') ||
        raw.contains("id='app'") ||
        raw.contains('id="__next"') ||
        raw.contains("id='__next'") ||
        raw.contains('__nuxt') ||
        raw.contains('nuxt_data') ||
        raw.contains('window.__') ||
        raw.contains('data-server-rendered');
  }

  bool _looksLikeSvelteKitDocument(Document document) =>
      document.querySelector('script[data-sveltekit-fetched]') != null ||
      document.outerHtml.toLowerCase().contains('__sveltekit_');

  Future<SourceMangaPage?> _listFromApi({
    required int page,
    required String query,
    required String order,
  }) async {
    for (final url in _apiCandidates(page: page, query: query, order: order)) {
      try {
        final response = await _getJson(url);
        if (response.statusCode != 200) continue;
        final decoded = jsonDecode(response.body);
        final mangas = _parseJsonMangas(decoded);
        if (mangas.isEmpty) continue;
        final totalPages = int.tryParse(
          response.headers['x-wp-totalpages'] ?? '',
        );
        return SourceMangaPage(
          mangas: mangas,
          hasNextPage:
              _jsonHasNextPage(decoded, page) ??
              (totalPages == null ? mangas.length >= 20 : page < totalPages),
        );
      } catch (_) {
        // Endpoint is optional; continue to the next common API shape.
      }
    }
    return null;
  }

  bool? _jsonHasNextPage(Object? decoded, int page) {
    for (final map in _jsonMaps([decoded])) {
      final current = int.tryParse(
        _valueString(
              _mapValue(map, const ['current_page', 'currentpage', 'page']),
            ) ??
            '',
      );
      final last = int.tryParse(
        _valueString(
              _mapValue(map, const ['last_page', 'lastpage', 'total_pages']),
            ) ??
            '',
      );
      if (current != null && last != null) return current < last;
      if (last != null) return page < last;
      final hasNext = _mapValue(map, const [
        'has_next_page',
        'hasnextpage',
        'hasnext',
        'next_page',
      ]);
      if (hasNext is bool) return hasNext;
      if (hasNext is num) return hasNext > 0;
      if (hasNext is String && hasNext.trim().isNotEmpty) {
        return hasNext != 'false' && hasNext != '0';
      }
    }
    return null;
  }

  List<Uri> _apiCandidates({
    required int page,
    required String query,
    required String order,
  }) {
    final base = Uri.parse(baseUrl);
    final api = _apiBase(base);
    final common = <String, String>{
      'page': '$page',
      if (query.isNotEmpty) 'search': query,
      if (query.isNotEmpty) 'q': query,
      'sort': order,
    };
    final heanQuery = <String, String>{
      'query_string': query,
      'status': 'All',
      'series_status': 'All',
      'order': 'desc',
      'orderBy': order == 'update' ? 'latest' : 'total_views',
      'series_type': 'Comic',
      'page': '$page',
      'perPage': '24',
      'tags_ids': '[]',
      'adult': 'true',
    };
    return [
      api.resolve('/query').replace(queryParameters: heanQuery),
      base.resolve('/query').replace(queryParameters: heanQuery),
      base.resolve('/api/query').replace(queryParameters: heanQuery),
      base
          .resolve('/wp-json/wp/v2/manga')
          .replace(
            queryParameters: {
              'page': '$page',
              'per_page': '24',
              '_embed': '1',
              if (query.isNotEmpty) 'search': query,
            },
          ),
      base.resolve('/api/manga').replace(queryParameters: common),
      base.resolve('/api/mangas').replace(queryParameters: common),
      base.resolve('/api/comics').replace(queryParameters: common),
      base.resolve('/api/series').replace(queryParameters: common),
      api.resolve('/manga').replace(queryParameters: common),
      api.resolve('/mangas').replace(queryParameters: common),
      api.resolve('/comics').replace(queryParameters: common),
      api.resolve('/series').replace(queryParameters: common),
    ];
  }

  List<Uri> _listingCandidates({
    required int page,
    required String query,
    required String order,
  }) {
    final base = Uri.parse(baseUrl);
    if (query.trim().isNotEmpty) {
      return [
        base
            .resolve('/')
            .replace(
              queryParameters: {
                's': query,
                if (_isToongod) 'post_type': 'wp-manga',
              },
            ),
        base
            .resolve('/manga/')
            .replace(
              queryParameters: {
                'title': query,
                'page': '$page',
                'order': order,
              },
            ),
        base
            .resolve('/comic/')
            .replace(queryParameters: {'s': query, 'page': '$page'}),
        base
            .resolve('/comics/')
            .replace(queryParameters: {'s': query, 'page': '$page'}),
        base
            .resolve('/series/')
            .replace(queryParameters: {'s': query, 'page': '$page'}),
        base
            .resolve('/search/')
            .replace(queryParameters: {'q': query, 'page': '$page'}),
        base
            .resolve('/search')
            .replace(queryParameters: {'keyword': query, 'page': '$page'}),
        base
            .resolve('/filterList')
            .replace(queryParameters: {'keyword': query, 'page': '$page'}),
      ];
    }
    return [
      if (_isToongod)
        base
            .resolve(page <= 1 ? '/webtoons/' : '/webtoons/page/$page/')
            .replace(
              queryParameters: {
                'm_orderby': order == 'update' ? 'latest' : 'trending',
              },
            ),
      // Toongod menaruh katalog manhwa di route khusus ini, bukan di
      // `/manga/`. Taruh paling awal supaya halaman katalog yang benar
      // dipakai sebelum fallback theme umum mencoba route lain.
      base.resolve('/webtoons/').replace(queryParameters: {'page': '$page'}),
      base.resolve('/webtoon/').replace(queryParameters: {'page': '$page'}),
      base.resolve('/webton/').replace(queryParameters: {'page': '$page'}),
      base.resolve('/manhwa/').replace(queryParameters: {'page': '$page'}),
      base
          .resolve('/manga/')
          .replace(queryParameters: {'page': '$page', 'order': order}),
      base.resolve('/comics/').replace(queryParameters: {'page': '$page'}),
      base.resolve('/comic/').replace(queryParameters: {'page': '$page'}),
      base.resolve('/komik/').replace(queryParameters: {'page': '$page'}),
      base.resolve('/series/').replace(queryParameters: {'page': '$page'}),
      base.resolve('/webtoon/').replace(queryParameters: {'page': '$page'}),
      base.resolve('/titles/').replace(queryParameters: {'page': '$page'}),
      base.resolve('/browse/').replace(queryParameters: {'page': '$page'}),
      base.resolve('/directory/').replace(queryParameters: {'page': '$page'}),
      base.resolve('/catalog/').replace(queryParameters: {'page': '$page'}),
      base.resolve('/project/').replace(queryParameters: {'page': '$page'}),
      base.resolve('/latest/').replace(queryParameters: {'page': '$page'}),
      base.resolve('/updates/').replace(queryParameters: {'page': '$page'}),
      base
          .resolve('/daftar-komik/')
          .replace(queryParameters: {'page': '$page'}),
      base
          .resolve('/')
          .replace(queryParameters: page > 1 ? {'page': '$page'} : null),
    ];
  }

  List<SourceManga> _parseMangaCards(Document document) {
    final selectors = [
      '.listupd .bs .bsx',
      '.utao .uta .imgu',
      '.page-item-detail',
      '.c-tabs-item__content',
      '.manga__item',
      '.manga-item',
      '.comic-item',
      '.series-item',
      '.post-item',
      '.item-summary',
      '.row.c-tabs-item__content',
      '[data-manga-id]',
      '[data-testid*="manga"]',
      '[data-testid*="comic"]',
      '.postbody article',
      'article',
    ];
    final result = <SourceManga>[];
    final seen = <String>{};
    for (final selector in selectors) {
      for (final el in document.querySelectorAll(selector)) {
        final manga = _cardFromElement(el);
        if (manga == null || !seen.add(manga.url)) continue;
        result.add(manga);
      }
      if (result.length >= 6) return result;
    }

    for (final manga in _parseEmbeddedMangas(document)) {
      if (seen.add(manga.url)) result.add(manga);
    }
    if (result.length >= 6) return result.take(40).toList();

    for (final a in document.querySelectorAll(
      'a[href*="/manga/"], a[href*="/comic/"], a[href*="/komik/"], '
      'a[href*="/series/"], a[href*="/webtoon/"], a[href*="/title/"]',
    )) {
      final manga = _cardFromAnchor(a);
      if (manga == null || !seen.add(manga.url)) continue;
      result.add(manga);
    }
    return result.take(40).toList();
  }

  List<Object?> _embeddedJsonValues(Document document) {
    final values = <Object?>[];
    for (final script in document.querySelectorAll(
      'script[type="application/json"], script[type="application/ld+json"], '
      'script#__NEXT_DATA__',
    )) {
      final raw = script.text.trim();
      if (raw.isEmpty) continue;
      if (raw.length > _maxEmbeddedJsonScriptLength) continue;
      try {
        values.add(jsonDecode(raw));
      } on FormatException {
        // Some sites label JavaScript as JSON. The URL regex stays as fallback.
      }
    }
    for (final script in document.querySelectorAll('script:not([src])')) {
      final raw = script.text.trim();
      if (raw.isEmpty ||
          raw.length > _maxInlineJsonScriptLength ||
          !(raw.contains('__NUXT__') ||
              raw.contains('__INITIAL_STATE__') ||
              raw.contains('__APOLLO_STATE__') ||
              raw.contains('__NEXT_DATA__') ||
              raw.contains('pageProps') ||
              raw.contains('manga') ||
              raw.contains('chapter'))) {
        continue;
      }
      for (final candidate in _jsonCandidatesFromScript(raw)) {
        try {
          values.add(jsonDecode(candidate));
        } on FormatException {
          // Inline JavaScript can contain non-JSON syntax; skip that candidate.
        }
      }
    }
    return values;
  }

  List<String> _jsonCandidatesFromScript(String raw) {
    final candidates = <String>[];
    for (final marker in [
      'window.__NUXT__',
      'self.__NUXT__',
      '__NUXT__',
      'window.__INITIAL_STATE__',
      '__INITIAL_STATE__',
      'window.__APOLLO_STATE__',
      '__APOLLO_STATE__',
    ]) {
      final markerIndex = raw.indexOf(marker);
      if (markerIndex < 0) continue;
      final start = raw.indexOf(RegExp(r'[\{\[]'), markerIndex);
      if (start < 0) continue;
      final end = _matchingJsonEnd(raw, start);
      if (end > start) candidates.add(raw.substring(start, end + 1));
    }
    final firstObject = raw.indexOf('{');
    if (firstObject >= 0 &&
        (raw.contains('"manga"') ||
            raw.contains('"series"') ||
            raw.contains('"chapters"') ||
            raw.contains('"pages"'))) {
      final end = _matchingJsonEnd(raw, firstObject);
      if (end > firstObject) {
        candidates.add(raw.substring(firstObject, end + 1));
      }
    }
    return candidates;
  }

  int _matchingJsonEnd(String raw, int start) {
    final open = raw[start];
    final close = open == '{' ? '}' : ']';
    var depth = 0;
    var inString = false;
    var escape = false;
    for (var i = start; i < raw.length; i++) {
      final ch = raw[i];
      if (escape) {
        escape = false;
        continue;
      }
      if (ch == '\\') {
        escape = inString;
        continue;
      }
      if (ch == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;
      if (ch == open) depth++;
      if (ch == close) {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  List<Map<String, Object?>> _embeddedJsonMaps(Document document) {
    return _jsonMaps(_embeddedJsonValues(document));
  }

  List<Map<String, Object?>> _jsonMaps(Iterable<Object?> values) {
    final result = <Map<String, Object?>>[];
    var visited = 0;

    void walk(Object? value, int depth) {
      if (depth > 8 || visited++ > 800 || result.length > 400) return;
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
        if (trimmed.length > 1 &&
            (trimmed.startsWith('{') || trimmed.startsWith('[')) &&
            (trimmed.contains('manga') ||
                trimmed.contains('comic') ||
                trimmed.contains('series') ||
                trimmed.contains('chapter') ||
                trimmed.contains('image') ||
                trimmed.contains('cover'))) {
          try {
            walk(jsonDecode(trimmed), depth + 1);
          } on FormatException {
            // Not a strict JSON string; keep walking other captured payloads.
          }
        }
      }
    }

    for (final value in values) {
      walk(value, 0);
    }
    return result;
  }

  Object? _mapValue(Map<String, Object?> map, List<String> keys) {
    final wanted = keys.toSet();
    for (final entry in map.entries) {
      if (wanted.contains(entry.key.toLowerCase())) return entry.value;
    }
    return null;
  }

  String? _valueString(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return _decodeEmbeddedUrl(value);
    }
    if (value is num || value is bool) return value.toString();
    if (value is List) {
      for (final nested in value) {
        final string = _valueString(nested);
        if (string != null) return string;
      }
    }
    if (value is Map) {
      final map = <String, Object?>{
        for (final entry in value.entries) '${entry.key}': entry.value,
      };
      return _valueString(
        _mapValue(map, const [
          'url',
          'src',
          'href',
          'path',
          'rendered',
          'source_url',
          'sourceurl',
          'value',
          'text',
          'name',
          'title',
          'label',
          'original',
          'default',
        ]),
      );
    }
    return null;
  }

  List<String> _valueStrings(Object? value) {
    if (value is String) {
      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (value is List) {
      return value.expand((nested) => _valueStrings(nested)).toSet().toList();
    }
    if (value is Map) {
      final map = <String, Object?>{
        for (final entry in value.entries) '${entry.key}': entry.value,
      };
      final label = _mapValue(map, const ['name', 'title', 'label']);
      return label == null ? const [] : _valueStrings(label);
    }
    return const [];
  }

  List<SourceManga> _parseEmbeddedMangas(Document document) {
    return _parseMangasFromMaps(_embeddedJsonMaps(document));
  }

  List<SourceManga> _parseJsonMangas(Object? decoded) {
    return _parseMangasFromMaps(_jsonMaps([decoded]));
  }

  List<SourceManga> _parseMangasFromMaps(Iterable<Map<String, Object?>> maps) {
    final result = <SourceManga>[];
    final seen = <String>{};
    for (final map in maps) {
      final title = _valueString(
        _mapValue(map, const [
          'title',
          'name',
          'manga_title',
          'comic_title',
          'post_title',
        ]),
      );
      if (title == null || title.length < 2 || title.length > 180) continue;
      var href = _valueString(
        _mapValue(map, const ['url', 'href', 'link', 'permalink', 'path']),
      );
      final slug = _valueString(
        _mapValue(map, const ['slug', 'series_slug', 'manga_slug']),
      );
      final id = _valueString(
        _mapValue(map, const ['id', 'series_id', 'manga_id']),
      );
      if (href == null && slug != null) {
        final heanLike =
            id != null &&
            (map.containsKey('series_slug') ||
                map.containsKey('series_status') ||
                map.containsKey('total_views') ||
                map.containsKey('seasons'));
        href = heanLike ? '/series/$slug#$id' : '/manga/$slug/';
      }
      if (href == null || href.startsWith('data:')) continue;

      final image = _valueString(
        _mapValue(map, const [
          'cover',
          'coverurl',
          'cover_url',
          'thumbnail',
          'thumbnailurl',
          'thumbnail_url',
          'featured_image',
          'featuredimage',
          'featured_media_url',
          'jetpack_featured_media_url',
          'source_url',
          'image',
          'image_url',
          'img_url',
          'b2key',
          'poster',
        ]),
      );
      final contentUrl = _absUrl(href);
      final path = Uri.tryParse(contentUrl)?.path.toLowerCase() ?? '';
      final looksLikeContent =
          path.contains('/manga') ||
          path.contains('/comic') ||
          path.contains('/komik') ||
          path.contains('/series') ||
          path.contains('/webtoon') ||
          path.contains('/title') ||
          path.contains('/project') ||
          (slug != null && image != null);
      if (!looksLikeContent || !seen.add(contentUrl)) continue;
      final thumbnailUrl = _thumbnailUrlFromMap(map, image);
      result.add(
        SourceManga(
          url: contentUrl,
          title: title,
          thumbnailUrl: thumbnailUrl,
          headers: _headersForAsset(thumbnailUrl),
        ),
      );
    }
    return result;
  }

  String? _thumbnailUrlFromMap(Map<String, Object?> map, String? image) {
    final b2key = _valueString(_mapValue(map, const ['b2key']));
    if (b2key != null &&
        b2key == image &&
        !b2key.contains('://') &&
        !b2key.contains(' ') &&
        _isRealImageUrl(b2key)) {
      return 'https://meo.comick.pictures/$b2key';
    }
    if (_isRealImageUrl(image)) return _absUrl(image!);
    return null;
  }

  SourceManga? _cardFromElement(Element el) {
    final a =
        el.querySelector('a[title]') ??
        el.querySelector('h3 a, h2 a, .tt a, .post-title a, a');
    if (a == null) return null;
    return _cardFromAnchor(a, root: el);
  }

  SourceManga? _cardFromAnchor(Element a, {Element? root}) {
    final href = a.attributes['href'];
    if (href == null || href.isEmpty || href.startsWith('#')) return null;
    final img = (root ?? a).querySelector('img') ?? a.querySelector('img');
    final title =
        a.attributes['title']?.trim().ifEmptyNull() ??
        img?.attributes['alt']?.trim().ifEmptyNull() ??
        a.text.trim().replaceAll(RegExp(r'\s+'), ' ').ifEmptyNull();
    if (title == null || title.length < 2) return null;
    final normalizedTitle = title.toLowerCase();
    if (normalizedTitle.contains('chapter') ||
        normalizedTitle == 'home' ||
        normalizedTitle == 'next' ||
        normalizedTitle == 'previous') {
      return null;
    }
    final thumbnailUrl = img == null ? null : _imgAttr(img);
    return SourceManga(
      url: _absUrl(href),
      title: title,
      thumbnailUrl: thumbnailUrl,
      headers: _headersForAsset(thumbnailUrl),
    );
  }

  bool _hasNextPage(Document document) =>
      document.querySelector(
        '.pagination .next, .nav-links .next, a.next, .hpage .r, '
        'a.nextpostslink, .wp-pagenavi .nextpostslink',
      ) !=
      null;

  @override
  Future<SourceMangaDetails> fetchMangaDetails(String mangaUrl) async {
    final document = await _getHtml(Uri.parse(mangaUrl));
    var description = document
        .querySelectorAll(
          '.desc, .summary__content, .description, .entry-content[itemprop=description], .entry-content',
        )
        .map((e) => e.text.trim())
        .where((s) => s.length > 20)
        .take(1)
        .join('\n');
    var genres = document
        .querySelectorAll('.mgen a, .genres a, .genre a, .seriestugenre a')
        .map((e) => e.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final thumb = document.querySelector(
      '.thumb img, .summary_image img, .infomanga img, img[itemprop=image]',
    );
    String? jsonAuthor;
    String? jsonArtist;
    String? jsonThumb;
    var jsonStatus = SourceMangaStatus.unknown;
    for (final map in _embeddedJsonMaps(document)) {
      description = description.isNotEmpty
          ? description
          : _valueString(
                  _mapValue(map, const [
                    'description',
                    'summary',
                    'synopsis',
                    'content',
                  ]),
                ) ??
                '';
      jsonAuthor ??= _valueString(
        _mapValue(map, const ['author', 'authors', 'writer']),
      );
      jsonArtist ??= _valueString(_mapValue(map, const ['artist', 'artists']));
      if (genres.isEmpty) {
        genres = _valueStrings(
          _mapValue(map, const ['genres', 'genre', 'categories', 'tags']),
        );
      }
      jsonThumb ??= _valueString(
        _mapValue(map, const [
          'cover',
          'coverurl',
          'cover_url',
          'thumbnail',
          'thumbnail_url',
          'image',
          'poster',
          'featured_image',
        ]),
      );
      final status = _valueString(
        _mapValue(map, const ['status']),
      )?.toLowerCase();
      jsonStatus = switch (status) {
        'ongoing' || 'publishing' => SourceMangaStatus.ongoing,
        'completed' || 'complete' || 'finished' => SourceMangaStatus.completed,
        'hiatus' => SourceMangaStatus.hiatus,
        'cancelled' || 'canceled' => SourceMangaStatus.cancelled,
        _ => jsonStatus,
      };
    }
    final htmlDetails = SourceMangaDetails(
      description: description.isEmpty ? null : description,
      author: jsonAuthor,
      artist: jsonArtist,
      genres: genres,
      status: jsonStatus,
      thumbnailUrl:
          (thumb == null ? null : _imgAttr(thumb)) ??
          (_isRealImageUrl(jsonThumb) ? _absUrl(jsonThumb!) : null),
    );
    if (htmlDetails.description != null ||
        htmlDetails.author != null ||
        htmlDetails.artist != null ||
        htmlDetails.genres.isNotEmpty ||
        htmlDetails.thumbnailUrl != null) {
      return htmlDetails;
    }
    return await _detailsFromApi(mangaUrl) ?? htmlDetails;
  }

  Future<SourceMangaDetails?> _detailsFromApi(String mangaUrl) async {
    final slug = _slugFromUrl(mangaUrl);
    if (slug == null) return null;
    for (final url in _detailsApiCandidates(slug)) {
      try {
        final response = await _getJson(url);
        if (response.statusCode != 200) continue;
        final maps = _jsonMaps([jsonDecode(response.body)]);
        for (final map in maps) {
          final title = _valueString(_mapValue(map, const ['title', 'name']));
          final mapSlug = _valueString(
            _mapValue(map, const ['slug', 'series_slug', 'manga_slug']),
          );
          if (title == null && mapSlug != slug) continue;
          final description = _valueString(
            _mapValue(map, const ['description', 'summary', 'synopsis']),
          );
          final genres = _valueStrings(
            _mapValue(map, const ['genres', 'genre', 'categories', 'tags']),
          );
          final thumb = _valueString(
            _mapValue(map, const [
              'cover',
              'coverurl',
              'cover_url',
              'thumbnail',
              'thumbnail_url',
              'image',
              'image_url',
              'poster',
            ]),
          );
          final status = _valueString(
            _mapValue(map, const ['status', 'series_status']),
          )?.toLowerCase();
          return SourceMangaDetails(
            description: description,
            author: _valueString(_mapValue(map, const ['author', 'authors'])),
            artist: _valueString(_mapValue(map, const ['artist', 'studio'])),
            genres: genres,
            status: switch (status) {
              'ongoing' || 'publishing' => SourceMangaStatus.ongoing,
              'completed' ||
              'complete' ||
              'finished' => SourceMangaStatus.completed,
              'hiatus' => SourceMangaStatus.hiatus,
              'dropped' ||
              'cancelled' ||
              'canceled' => SourceMangaStatus.cancelled,
              _ => SourceMangaStatus.unknown,
            },
            thumbnailUrl: _isRealImageUrl(thumb) ? _absUrl(thumb!) : null,
          );
        }
      } catch (_) {
        // Detail API is optional; keep trying other common shapes.
      }
    }
    return null;
  }

  List<Uri> _detailsApiCandidates(String slug) {
    final base = Uri.parse(baseUrl);
    final api = _apiBase(base);
    return [
      api.resolve('/series/$slug'),
      api.resolve('/manga/$slug'),
      api.resolve('/comic/$slug'),
      base.resolve('/api/series/$slug'),
      base.resolve('/api/manga/$slug'),
      base.resolve('/api/comic/$slug'),
    ];
  }

  @override
  Future<List<SourceChapter>> fetchChapterList(String mangaUrl) async {
    final document = await _getHtml(Uri.parse(mangaUrl));
    final seen = <String>{};
    final chapters = _chaptersFromDocument(document, seen);
    if (chapters.isEmpty) {
      final rendered = await _getRenderedHtml(Uri.parse(mangaUrl));
      if (rendered != null) {
        chapters.addAll(_chaptersFromDocument(rendered, seen));
      }
    }
    if (chapters.isEmpty) {
      chapters.addAll(await _chapterListFromApi(mangaUrl, seen));
    }
    if (chapters.isEmpty) {
      throw MangaSourceException('Daftar chapter $name belum dikenali.');
    }
    return chapters;
  }

  List<SourceChapter> _chaptersFromDocument(
    Document document,
    Set<String> seen,
  ) {
    final links = <Element>[
      ...document.querySelectorAll(
        '#chapterlist a, .eplister a, .listing-chapters_wrap a, '
        '.wp-manga-chapter a, .chapter-list a, .cl a, .bxcl a, '
        '.episodelist a, .lchx a, .eph-num a, [data-chapter] a, '
        '[class*="chapter"] a',
      ),
      ...document.querySelectorAll('a[href*="chapter"], a[href*="episode"]'),
    ];
    final chapters = <SourceChapter>[];
    for (final a in links) {
      final href = a.attributes['href'];
      if (href == null || href.isEmpty || !seen.add(_absUrl(href))) continue;
      final text = a.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      final name = text.ifEmptyNull() ?? _chapterNameFromUrl(href);
      if (!_looksLikeChapter(name, href)) continue;
      chapters.add(
        SourceChapter(
          url: _absUrl(href),
          name: name,
          dateUpload: _chapterDateNear(a),
        ),
      );
    }
    for (final map in _embeddedJsonMaps(document)) {
      var href = _valueString(
        _mapValue(map, const [
          'url',
          'href',
          'link',
          'permalink',
          'chapter_url',
        ]),
      );
      final slug = _valueString(_mapValue(map, const ['slug']));
      final chapterName = _valueString(
        _mapValue(map, const [
          'chapter_name',
          'chaptername',
          'title',
          'name',
          'number',
          'chapter',
        ]),
      );
      if (href == null &&
          slug != null &&
          slug.toLowerCase().contains('chapter')) {
        href = '/chapter/$slug/';
      }
      if (href == null) continue;
      final resolved = _absUrl(href);
      final displayName = chapterName ?? _chapterNameFromUrl(href);
      if (!_looksLikeChapter(displayName, resolved) || !seen.add(resolved)) {
        continue;
      }
      chapters.add(
        SourceChapter(
          url: resolved,
          name: displayName,
          dateUpload: _chapterDateFromMap(map),
        ),
      );
    }
    return chapters;
  }

  /// Theme Madara (termasuk Toongod) menaruh tanggal sebagai saudara link
  /// chapter di `.chapter-release-date`, bukan di dalam tag `<a>`-nya.
  /// Naik beberapa tingkat saja supaya tanggal manga lain di halaman tidak
  /// ikut tersangkut ke chapter yang salah.
  DateTime? _chapterDateNear(Element anchor) {
    Element? row = anchor;
    for (var depth = 0; depth < 5 && row != null; depth++) {
      final time = row.querySelector('time');
      final dateValue =
          time?.attributes['datetime'] ??
          time?.attributes['title'] ??
          row.attributes['data-date'] ??
          row.attributes['data-time'];
      final fromAttribute = _parseUniversalChapterDate(dateValue);
      if (fromAttribute != null) return fromAttribute;

      final dateElement = row.querySelector(
        '.chapter-release-date, .chapterdate, .chapter-date, '
        '.post-on, [class*="chapter-date"], [class*="release-date"]',
      );
      final fromText = _parseUniversalChapterDate(dateElement?.text);
      if (fromText != null) return fromText;

      row = row.parent;
      if (row?.localName == 'body' || row?.localName == 'html') break;
    }
    return null;
  }

  DateTime? _chapterDateFromMap(Map<String, Object?> map) {
    final raw = _valueString(
      _mapValue(map, const [
        'date_upload',
        'dateupload',
        'release_date',
        'released_at',
        'published_at',
        'updated_at',
        'created_at',
        'date',
      ]),
    );
    return _parseUniversalChapterDate(raw);
  }

  DateTime? _parseUniversalChapterDate(String? raw) {
    if (raw == null) return null;
    var value = raw
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (value.isEmpty) return null;

    final timestamp = int.tryParse(value);
    if (timestamp != null && timestamp > 1000000000) {
      return DateTime.fromMillisecondsSinceEpoch(
        timestamp < 100000000000 ? timestamp * 1000 : timestamp,
      );
    }

    final iso = DateTime.tryParse(value);
    if (iso != null) return iso;

    value = value
        .replaceFirst(
          RegExp(
            r'^(updated|published|released|upload(?:ed)?|rilis)\s*:?\s*',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'(\d)(st|nd|rd|th)\b', caseSensitive: false), r'$1')
        .trim();
    final lower = value.toLowerCase();
    final now = DateTime.now();
    if (lower == 'yesterday' || lower == 'kemarin') {
      return now.subtract(const Duration(days: 1));
    }
    if (lower == 'today' || lower == 'hari ini' || lower == 'just now') {
      return now;
    }

    final relative = RegExp(
      r'(\d+)\s*(second|minute|hour|day|week|month|year|detik|menit|jam|hari|minggu|bulan|tahun)s?(?:\s+ago|\s+lalu)?',
      caseSensitive: false,
    ).firstMatch(lower);
    if (relative != null) {
      final amount = int.parse(relative.group(1)!);
      final unit = relative.group(2)!;
      final duration = switch (unit) {
        'second' || 'detik' => Duration(seconds: amount),
        'minute' || 'menit' => Duration(minutes: amount),
        'hour' || 'jam' => Duration(hours: amount),
        'day' || 'hari' => Duration(days: amount),
        'week' || 'minggu' => Duration(days: amount * 7),
        'month' || 'bulan' => Duration(days: amount * 30),
        _ => Duration(days: amount * 365),
      };
      return now.subtract(duration);
    }

    final numeric = RegExp(
      r'^(\d{1,2})[./-](\d{1,2})[./-](\d{4})$',
    ).firstMatch(value);
    if (numeric != null) {
      return DateTime(
        int.parse(numeric.group(3)!),
        int.parse(numeric.group(2)!),
        int.parse(numeric.group(1)!),
      );
    }

    final monthFirst = RegExp(
      r'^([A-Za-z]+)\s+(\d{1,2}),?\s+(\d{4})$',
    ).firstMatch(value);
    if (monthFirst != null) {
      final month = _englishMonth(monthFirst.group(1)!);
      if (month != null) {
        return DateTime(
          int.parse(monthFirst.group(3)!),
          month,
          int.parse(monthFirst.group(2)!),
        );
      }
    }

    // Format resmi extension Toongod: `d MMM yyyy`, mis. `20 Jul 2026`.
    final dayFirst = RegExp(
      r'^(\d{1,2})\s+([A-Za-z]+),?\s+(\d{4})$',
    ).firstMatch(value);
    if (dayFirst == null) return null;
    final month = _englishMonth(dayFirst.group(2)!);
    if (month == null) return null;
    return DateTime(
      int.parse(dayFirst.group(3)!),
      month,
      int.parse(dayFirst.group(1)!),
    );
  }

  int? _englishMonth(String value) {
    const months = {
      'jan': 1,
      'january': 1,
      'feb': 2,
      'february': 2,
      'mar': 3,
      'march': 3,
      'apr': 4,
      'april': 4,
      'may': 5,
      'jun': 6,
      'june': 6,
      'jul': 7,
      'july': 7,
      'aug': 8,
      'august': 8,
      'sep': 9,
      'sept': 9,
      'september': 9,
      'oct': 10,
      'october': 10,
      'nov': 11,
      'november': 11,
      'dec': 12,
      'december': 12,
    };
    return months[value.toLowerCase()];
  }

  Future<List<SourceChapter>> _chapterListFromApi(
    String mangaUrl,
    Set<String> seen,
  ) async {
    final chapters = <SourceChapter>[];
    for (final url in _chapterApiCandidates(mangaUrl)) {
      try {
        final response = await _getJson(url);
        if (response.statusCode != 200) continue;
        final decoded = jsonDecode(response.body);
        final maps = _jsonMaps([decoded]);
        final fromMaps = _chaptersFromMaps(
          maps,
          mangaUrl: mangaUrl,
          seen: seen,
        );
        if (fromMaps.isNotEmpty) {
          chapters.addAll(fromMaps);
          break;
        }
      } catch (_) {
        // Endpoint bentuk ini tidak ada di source tersebut.
      }
    }
    return chapters;
  }

  List<SourceChapter> _chaptersFromMaps(
    Iterable<Map<String, Object?>> maps, {
    required String mangaUrl,
    required Set<String> seen,
  }) {
    final seriesSlug = _slugFromUrl(mangaUrl);
    final chapters = <SourceChapter>[];
    for (final map in maps) {
      var href = _valueString(
        _mapValue(map, const [
          'url',
          'href',
          'link',
          'permalink',
          'chapter_url',
        ]),
      );
      final chapterSlug = _valueString(
        _mapValue(map, const ['chapter_slug', 'slug']),
      );
      final chapterId = _valueString(
        _mapValue(map, const ['id', 'chapter_id']),
      );
      if (href == null && seriesSlug != null && chapterSlug != null) {
        href =
            '/series/$seriesSlug/$chapterSlug'
            '${chapterId == null ? '' : '#$chapterId'}';
      }
      if (href == null) continue;
      final name =
          _valueString(
            _mapValue(map, const [
              'chapter_name',
              'chaptername',
              'chapter_title',
              'title',
              'name',
              'number',
              'chapter',
            ]),
          ) ??
          _chapterNameFromUrl(href);
      final resolved = _absUrl(href);
      if (!_looksLikeChapter(name, resolved) || !seen.add(resolved)) continue;
      chapters.add(
        SourceChapter(
          url: resolved,
          name: name,
          dateUpload: _chapterDateFromMap(map),
        ),
      );
    }
    return chapters;
  }

  List<Uri> _chapterApiCandidates(String mangaUrl) {
    final base = Uri.parse(baseUrl);
    final api = _apiBase(base);
    final slug = _slugFromUrl(mangaUrl);
    final fragment = Uri.tryParse(mangaUrl)?.fragment ?? '';
    final id = fragment.ifEmptyNull();
    return [
      if (id != null)
        api
            .resolve('/chapter/query')
            .replace(
              queryParameters: {
                'page': '1',
                'perPage': '1000',
                'series_id': id,
              },
            ),
      if (id != null)
        base
            .resolve('/api/chapter/query')
            .replace(
              queryParameters: {
                'page': '1',
                'perPage': '1000',
                'series_id': id,
              },
            ),
      if (slug != null) api.resolve('/series/$slug'),
      if (slug != null) api.resolve('/series/$slug/chapters'),
      if (slug != null) api.resolve('/manga/$slug/chapters'),
      if (slug != null) base.resolve('/api/series/$slug/chapters'),
      if (slug != null) base.resolve('/api/manga/$slug/chapters'),
      if (slug != null) base.resolve('/wp-json/wp-manga/v1/chapters/$slug'),
    ];
  }

  bool _looksLikeChapter(String name, String href) {
    final value = '$name $href'.toLowerCase();
    return value.contains('chapter') ||
        value.contains('ch.') ||
        value.contains('episode') ||
        value.contains('eps') ||
        RegExp(r'/(ch|chapter|episode|eps)[-/]?\d').hasMatch(value);
  }

  String _chapterNameFromUrl(String href) {
    final slug = Uri.parse(_absUrl(href)).pathSegments.lastOrNull ?? href;
    return slug.replaceAll('-', ' ').replaceAll('_', ' ').trim();
  }

  static final _quotedImageRegex = RegExp(
    r'''(?:https?:)?(?:\\?/){2}[^"'\\\s<>]+\.(?:jpg|jpeg|png|webp|avif)(?:\?[^"'\s<>]*)?|(?:\\?/)?(?:wp-content|uploads|images|image|img|storage|reader|pages|manga|doujin|doujindesu)(?:\\?/|[^"'\\\s<>])+\.(?:jpg|jpeg|png|webp|avif)(?:\?[^"'\s<>]*)?''',
    caseSensitive: false,
  );

  List<String> _embeddedImageUrls(Document document) {
    final urls = <String>[];

    void walk(Object? value, int depth) {
      if (depth > 8 || urls.length > 300) return;
      if (value is String) {
        final decoded = _decodeEmbeddedUrl(value);
        final trimmed = decoded.trim();
        if (trimmed.length > 1 &&
            (trimmed.startsWith('{') || trimmed.startsWith('[')) &&
            (trimmed.contains('.jpg') ||
                trimmed.contains('.jpeg') ||
                trimmed.contains('.png') ||
                trimmed.contains('.webp') ||
                trimmed.contains('.avif') ||
                trimmed.contains('image') ||
                trimmed.contains('pages'))) {
          try {
            walk(jsonDecode(trimmed), depth + 1);
            return;
          } on FormatException {
            // Inline scripts often contain JSON-ish strings; skip invalid ones.
          }
        }
        if (_isRealImageUrl(decoded)) urls.add(decoded);
      } else if (value is List) {
        for (final nested in value) {
          walk(nested, depth + 1);
        }
      } else if (value is Map) {
        for (final nested in value.values) {
          walk(nested, depth + 1);
        }
      }
    }

    for (final value in _embeddedJsonValues(document)) {
      walk(value, 0);
    }
    final rawHtml = document.outerHtml;
    if (rawHtml.length <= _maxRawImageScanLength) {
      urls.addAll(_imageUrlsFromRawText(rawHtml));
    }
    return urls.toSet().toList();
  }

  List<String> _imageUrlsFromRawText(String raw) {
    final urls = <String>[];
    for (final source in {raw, _decodeEmbeddedUrl(raw)}) {
      for (final match in _quotedImageRegex.allMatches(source)) {
        final rawUrl = match.group(0);
        if (rawUrl == null) continue;
        final trimmed = rawUrl.trimLeft();
        final startsLikeUrl =
            trimmed.startsWith('http://') ||
            trimmed.startsWith('https://') ||
            trimmed.startsWith('//') ||
            trimmed.startsWith('/') ||
            trimmed.startsWith(r'\/');
        if (!startsLikeUrl) continue;
        final relative = trimmed.startsWith('/') || trimmed.startsWith(r'\/');
        if (relative && match.start > 0) {
          final previous = source[match.start - 1];
          if (!RegExp(r'''[\s"'[\(=:,]''').hasMatch(previous)) continue;
        }
        final decoded = _decodeEmbeddedUrl(rawUrl);
        if (_isRealImageUrl(decoded)) urls.add(decoded);
      }
    }
    return urls.toSet().toList();
  }

  List<String> _imageUrlsFromJson(Object? decoded) {
    final urls = <String>[];

    void walk(Object? value, int depth) {
      if (depth > 18) return;
      if (value is String) {
        final decoded = _decodeEmbeddedUrl(value);
        if (_isRealImageUrl(decoded)) urls.add(decoded);
      } else if (value is List) {
        for (final nested in value) {
          walk(nested, depth + 1);
        }
      } else if (value is Map) {
        final map = <String, Object?>{
          for (final entry in value.entries) '${entry.key}': entry.value,
        };
        final direct = _valueString(
          _mapValue(map, const [
            'image',
            'image_url',
            'imageurl',
            'img',
            'src',
            'url',
            'path',
            'file',
            'b2key',
          ]),
        );
        final directUrl = direct;
        if (_isRealImageUrl(directUrl)) {
          final b2key = _valueString(_mapValue(map, const ['b2key']));
          if (b2key != null &&
              directUrl == b2key &&
              !directUrl!.contains('://')) {
            urls.add('https://meo.comick.pictures/$directUrl');
          } else {
            urls.add(directUrl!);
          }
        }
        for (final nested in map.values) {
          walk(nested, depth + 1);
        }
      }
    }

    walk(decoded, 0);
    return urls;
  }

  List<Uri> _pageApiCandidates(String chapterUrl) {
    final base = Uri.parse(baseUrl);
    final api = _apiBase(base);
    final uri = Uri.parse(_absUrl(chapterUrl));
    final path = uri.path;
    final slug = _slugFromUrl(chapterUrl);
    final apiPath = path.replaceFirst(
      RegExp(r'^/(series|manga|comic|komik)/'),
      '/chapter/',
    );
    return [
      api.resolve(apiPath),
      base.resolve('/api$apiPath'),
      if (slug != null) api.resolve('/chapter/$slug'),
      if (slug != null) api.resolve('/chapters/$slug'),
      if (slug != null) base.resolve('/api/chapter/$slug'),
      if (slug != null) base.resolve('/api/chapters/$slug'),
    ];
  }

  @override
  Future<List<SourcePage>> fetchPageList(String chapterUrl) async {
    final absoluteChapterUrl = _absUrl(chapterUrl);
    final document = await _getHtml(Uri.parse(absoluteChapterUrl));
    final seen = <String>{};
    final pages = <SourcePage>[];
    final pageHeaders = {..._headers, 'Referer': absoluteChapterUrl};
    pages.addAll(_pagesFromDocument(document, seen, pageHeaders));
    if (pages.isNotEmpty) return pages;

    final rendered = await _getRenderedHtml(Uri.parse(absoluteChapterUrl));
    if (rendered != null) {
      pages.addAll(_pagesFromDocument(rendered, seen, pageHeaders));
    }
    if (pages.isNotEmpty) return pages;

    for (final url in _pageApiCandidates(chapterUrl)) {
      try {
        final response = await _getJson(url);
        if (response.statusCode != 200) continue;
        for (final image in _imageUrlsFromJson(jsonDecode(response.body))) {
          final pageUrl = _absUrl(image);
          if (!_isRealImageUrl(pageUrl) || !seen.add(pageUrl)) continue;
          pages.add(
            SourcePage(
              index: pages.length,
              imageUrl: pageUrl,
              headers: pageHeaders,
            ),
          );
        }
        if (pages.isNotEmpty) return pages;
      } catch (_) {
        // API reader optional; continue.
      }
    }

    final rawHtml = document.outerHtml;
    if (rawHtml.length <= _maxRawImageScanLength) {
      for (final rawUrl in _imageUrlsFromRawText(rawHtml)) {
        final url = _absUrl(rawUrl);
        if (!_isRealImageUrl(url) || !seen.add(url)) continue;
        pages.add(
          SourcePage(index: pages.length, imageUrl: url, headers: pageHeaders),
        );
      }
    }
    if (pages.isEmpty) {
      throw MangaSourceException('Gambar chapter $name belum dikenali.');
    }
    return pages;
  }

  List<SourcePage> _pagesFromDocument(
    Document document,
    Set<String> seen,
    Map<String, String> pageHeaders,
  ) {
    final pages = <SourcePage>[];
    final imgs = document.querySelectorAll(
      '#readerarea img, .reading-content img, .chapter-content img, '
      '.entry-content img, .separator img, .page-break img, article img, main img',
    );
    for (final img in imgs) {
      final url = _imgAttr(img);
      if (url == null || !seen.add(url)) continue;
      pages.add(
        SourcePage(index: pages.length, imageUrl: url, headers: pageHeaders),
      );
    }
    for (final element in document.querySelectorAll(
      'picture source[srcset], link[rel=preload][as=image], '
      'meta[property="og:image"], meta[name="twitter:image"], '
      'a[href*=".jpg"], a[href*=".jpeg"], a[href*=".png"], '
      'a[href*=".webp"], a[href*=".avif"]',
    )) {
      final raw =
          element.attributes['srcset']
              ?.split(',')
              .first
              .trim()
              .split(' ')
              .first ??
          element.attributes['href'] ??
          element.attributes['content'];
      if (!_isRealImageUrl(raw)) continue;
      final url = _absUrl(_decodeEmbeddedUrl(raw!));
      if (!seen.add(url)) continue;
      pages.add(
        SourcePage(index: pages.length, imageUrl: url, headers: pageHeaders),
      );
    }
    for (final embeddedUrl in _embeddedImageUrls(document)) {
      final url = _absUrl(embeddedUrl);
      if (!seen.add(url)) continue;
      pages.add(
        SourcePage(index: pages.length, imageUrl: url, headers: pageHeaders),
      );
    }
    return pages;
  }
}

extension _StringExt on String {
  String? ifEmptyNull() => isEmpty ? null : this;
}
