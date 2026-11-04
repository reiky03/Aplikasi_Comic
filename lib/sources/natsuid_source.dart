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
  }) : _client = client ?? createKizenHttpClient();

  @override
  final String name;

  @override
  final String baseUrl;

  final http.Client _client;
  final _random = Random();
  String? _searchNonce;

  Map<String, String> get _headers => {
    'Referer': '$baseUrl/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    ...SourceSessionStore.headersFor(baseUrl),
  };

  Future<http.Response> _get(Uri url) async {
    try {
      return await _client.get(url, headers: _headers);
    } catch (e) {
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
      return await http.Response.fromStream(await _client.send(request));
    } catch (e) {
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
    final url = Uri.parse(
      '$baseUrl/wp-admin/admin-ajax.php',
    ).replace(queryParameters: {'type': 'search_form', 'action': 'get_nonce'});
    final response = await _get(url);
    if (response.statusCode != 200) {
      throw MangaSourceException(
        '$name gagal mengambil token pencarian '
        '(${response.statusCode}).',
      );
    }
    final nonce = html_parser
        .parseFragment(response.body)
        .querySelector('input[name="search_nonce"]')
        ?.attributes['value']
        ?.trim();
    if (nonce == null || nonce.isEmpty) {
      throw MangaSourceException('Token pencarian $name tidak ditemukan.');
    }
    _searchNonce = nonce;
    return nonce;
  }

  Future<SourceMangaPage> _advancedList({
    required int page,
    required String orderBy,
    String query = '',
    bool retryNonce = true,
  }) async {
    final nonce = await _getSearchNonce();
    final url = Uri.parse(
      '$baseUrl/wp-admin/admin-ajax.php',
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
      final segments = Uri.parse(baseUrl)
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

    final detailsUrl = Uri.parse('$baseUrl/wp-json/wp/v2/manga').replace(
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
    final url = Uri.parse('$baseUrl/wp-json/wp/v2/manga').replace(
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

  @override
  Future<SourceMangaPage> fetchPopular(int page) async {
    try {
      return await _advancedList(page: page, orderBy: 'popular');
    } catch (_) {
      return _legacyList(page: page);
    }
  }

  @override
  Future<SourceMangaPage> fetchLatest(int page) async {
    try {
      return await _advancedList(page: page, orderBy: 'updated');
    } catch (_) {
      return _legacyList(page: page, latest: true);
    }
  }

  @override
  Future<SourceMangaPage> fetchSearch(String query, int page) async {
    try {
      return await _advancedList(page: page, orderBy: 'popular', query: query);
    } catch (_) {
      return _legacyList(page: page, search: query);
    }
  }

  int _mangaId(String mangaUrl) =>
      ((jsonDecode(mangaUrl) as Map<String, dynamic>)['id'] as num).toInt();

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
