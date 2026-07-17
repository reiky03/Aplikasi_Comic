import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../data/source_session_store.dart';
import 'manga_source.dart';

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

  Future<Document> _getHtml(Uri url) async {
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
    final lower = response.body.toLowerCase();
    if (lower.contains('sedang maintenance') ||
        lower.contains('peningkatan server') ||
        lower.contains('under maintenance')) {
      throw MangaSourceException('$name sedang maintenance dari sisi website.');
    }
    if (lower.contains('/cdn-cgi/challenge-platform/') ||
        lower.contains('just a moment') ||
        lower.contains('error establishing a redis connection')) {
      throw MangaSourceException(
        '$name butuh sesi browser. Buka lewat WebView dulu.',
      );
    }
    return html_parser.parse(response.body);
  }

  Future<http.Response> _getJson(Uri url) => _client
      .get(url, headers: {..._headers, 'Accept': 'application/json'})
      .timeout(const Duration(seconds: 15));

  String _absUrl(String href) => Uri.parse(baseUrl).resolve(href).toString();

  String _decodeEmbeddedUrl(String value) => value
      .trim()
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
  Future<SourceMangaPage> fetchPopular(int page) => _list(page: page);

  @override
  Future<SourceMangaPage> fetchLatest(int page) =>
      _list(page: page, order: 'update');

  @override
  Future<SourceMangaPage> fetchSearch(String query, int page) =>
      _list(page: page, query: query);

  Future<SourceMangaPage> _list({
    required int page,
    String query = '',
    String order = 'popular',
  }) async {
    final urls = _listingCandidates(page: page, query: query, order: order);
    Object? lastError;
    for (final url in urls) {
      try {
        final document = await _getHtml(url);
        final mangas = _parseMangaCards(document);
        if (mangas.isNotEmpty) {
          return SourceMangaPage(
            mangas: mangas,
            hasNextPage: _hasNextPage(document),
          );
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
          hasNextPage: totalPages == null
              ? mangas.length >= 20
              : page < totalPages,
        );
      } catch (_) {
        // Endpoint is optional; continue to the next common API shape.
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
    final common = <String, String>{
      'page': '$page',
      if (query.isNotEmpty) 'search': query,
      if (query.isNotEmpty) 'q': query,
      'sort': order,
    };
    return [
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
        base.resolve('/').replace(queryParameters: {'s': query}),
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
      ];
    }
    return [
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
      base.resolve('/latest/').replace(queryParameters: {'page': '$page'}),
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
      try {
        values.add(jsonDecode(raw));
      } on FormatException {
        // Some sites label JavaScript as JSON. The URL regex stays as fallback.
      }
    }
    return values;
  }

  List<Map<String, Object?>> _embeddedJsonMaps(Document document) {
    return _jsonMaps(_embeddedJsonValues(document));
  }

  List<Map<String, Object?>> _jsonMaps(Iterable<Object?> values) {
    final result = <Map<String, Object?>>[];
    var visited = 0;

    void walk(Object? value, int depth) {
      if (depth > 16 || visited++ > 4000) return;
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
      final slug = _valueString(_mapValue(map, const ['slug']));
      href ??= slug == null ? null : '/manga/$slug/';
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
          (slug != null && image != null);
      if (!looksLikeContent || !seen.add(contentUrl)) continue;
      result.add(
        SourceManga(
          url: contentUrl,
          title: title,
          thumbnailUrl: _isRealImageUrl(image) ? _absUrl(image!) : null,
          headers: _headers,
        ),
      );
    }
    return result;
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
    return SourceManga(
      url: _absUrl(href),
      title: title,
      thumbnailUrl: img == null ? null : _imgAttr(img),
      headers: _headers,
    );
  }

  bool _hasNextPage(Document document) =>
      document.querySelector(
        '.pagination .next, .nav-links .next, a.next, .hpage .r',
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
    return SourceMangaDetails(
      description: description.isEmpty ? null : description,
      author: jsonAuthor,
      artist: jsonArtist,
      genres: genres,
      status: jsonStatus,
      thumbnailUrl:
          (thumb == null ? null : _imgAttr(thumb)) ??
          (_isRealImageUrl(jsonThumb) ? _absUrl(jsonThumb!) : null),
    );
  }

  @override
  Future<List<SourceChapter>> fetchChapterList(String mangaUrl) async {
    final document = await _getHtml(Uri.parse(mangaUrl));
    final links = <Element>[
      ...document.querySelectorAll(
        '#chapterlist a, .eplister a, .listing-chapters_wrap a, '
        '.wp-manga-chapter a, .chapter-list a, .cl a, .bxcl a, '
        '.episodelist a, .lchx a, .eph-num a, [data-chapter] a, '
        '[class*="chapter"] a',
      ),
      ...document.querySelectorAll('a[href*="chapter"], a[href*="episode"]'),
    ];
    final seen = <String>{};
    final chapters = <SourceChapter>[];
    for (final a in links) {
      final href = a.attributes['href'];
      if (href == null || href.isEmpty || !seen.add(_absUrl(href))) continue;
      final text = a.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      final name = text.ifEmptyNull() ?? _chapterNameFromUrl(href);
      if (!_looksLikeChapter(name, href)) continue;
      chapters.add(SourceChapter(url: _absUrl(href), name: name));
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
      chapters.add(SourceChapter(url: resolved, name: displayName));
    }
    if (chapters.isEmpty) {
      throw MangaSourceException('Daftar chapter $name belum dikenali.');
    }
    return chapters;
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
    r'''https?(?:\\?/|[^"'\\\s<>])+\.(?:jpg|jpeg|png|webp|avif)(?:\?[^"'\s<>]*)?''',
    caseSensitive: false,
  );

  List<String> _embeddedImageUrls(Document document) {
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
        for (final nested in value.values) {
          walk(nested, depth + 1);
        }
      }
    }

    for (final value in _embeddedJsonValues(document)) {
      walk(value, 0);
    }
    return urls;
  }

  @override
  Future<List<SourcePage>> fetchPageList(String chapterUrl) async {
    final document = await _getHtml(Uri.parse(chapterUrl));
    final imgs = document.querySelectorAll(
      '#readerarea img, .reading-content img, .chapter-content img, '
      '.entry-content img, .separator img, .page-break img, article img, main img',
    );
    final seen = <String>{};
    final pages = <SourcePage>[];
    final pageHeaders = {..._headers, 'Referer': chapterUrl};
    for (final img in imgs) {
      final url = _imgAttr(img);
      if (url == null || !seen.add(url)) continue;
      pages.add(
        SourcePage(index: pages.length, imageUrl: url, headers: pageHeaders),
      );
    }
    if (pages.isNotEmpty) return pages;

    for (final embeddedUrl in _embeddedImageUrls(document)) {
      final url = _absUrl(embeddedUrl);
      if (!seen.add(url)) continue;
      pages.add(
        SourcePage(index: pages.length, imageUrl: url, headers: pageHeaders),
      );
    }
    if (pages.isNotEmpty) return pages;

    for (final match in _quotedImageRegex.allMatches(document.outerHtml)) {
      final rawUrl = match.group(0);
      if (rawUrl == null) continue;
      final url = _absUrl(_decodeEmbeddedUrl(rawUrl));
      if (!_isRealImageUrl(url) || !seen.add(url)) continue;
      pages.add(
        SourcePage(index: pages.length, imageUrl: url, headers: pageHeaders),
      );
    }
    if (pages.isEmpty) {
      throw MangaSourceException('Gambar chapter $name belum dikenali.');
    }
    return pages;
  }
}

extension _StringExt on String {
  String? ifEmptyNull() => isEmpty ? null : this;
}
