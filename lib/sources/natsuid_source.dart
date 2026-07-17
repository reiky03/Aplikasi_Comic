import 'dart:convert';
import 'dart:math';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

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
  }) : _client = client ?? http.Client();

  @override
  final String name;

  @override
  final String baseUrl;

  final http.Client _client;
  final _random = Random();

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

  Future<SourceMangaPage> _list({required int page, String? search}) async {
    final url = Uri.parse('$baseUrl/wp-json/wp/v2/manga').replace(
      queryParameters: {
        'page': '$page',
        'per_page': '20',
        '_embed': '',
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final response = await _get(url);
    if (response.statusCode != 200) {
      throw MangaSourceException(
        '$name mengembalikan status ${response.statusCode}.',
      );
    }
    final list = (jsonDecode(response.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final mangas = list.map(_mangaFromJson).toList();
    final totalPagesHeader = response.headers['x-wp-totalpages'];
    final totalPages = int.tryParse(totalPagesHeader ?? '') ?? (page + 1);
    return SourceMangaPage(mangas: mangas, hasNextPage: page < totalPages);
  }

  SourceManga _mangaFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final slug = json['slug'] as String? ?? '';
    final title =
        (json['title'] as Map<String, dynamic>?)?['rendered'] as String? ?? '';
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
  Future<SourceMangaPage> fetchPopular(int page) => _list(page: page);

  @override
  Future<SourceMangaPage> fetchLatest(int page) => _list(page: page);

  @override
  Future<SourceMangaPage> fetchSearch(String query, int page) =>
      _list(page: page, search: query);

  int _mangaId(String mangaUrl) =>
      (jsonDecode(mangaUrl) as Map<String, dynamic>)['id'] as int;

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
    final json = jsonDecode(response.body) as Map<String, dynamic>;
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
