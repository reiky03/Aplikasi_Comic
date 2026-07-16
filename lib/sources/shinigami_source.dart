import 'dart:convert';

import 'package:http/http.dart' as http;

import 'manga_source.dart';

/// Parser native untuk Shinigami (https://g.shinigami.asia) — API JSON
/// murni (api.shngm.io), diporting dari extension Kotlin open-source
/// `keiyoushi/extensions-source` (src/id/shinigami) supaya jalan native
/// di Flutter tanpa perlu menjalankan APK Tachiyomi.
class ShinigamiSource implements MangaSource {
  ShinigamiSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _apiUrl = 'https://api.shngm.io';

  @override
  String get name => 'Shinigami';

  @override
  String get baseUrl => 'https://g.shinigami.asia';

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Origin': baseUrl,
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      };

  Future<Map<String, dynamic>> _getJson(Uri url) async {
    late final http.Response response;
    try {
      response = await _client.get(url, headers: _headers);
    } catch (e) {
      throw MangaSourceException('Gagal menghubungi $name: $e');
    }
    if (response.statusCode != 200) {
      throw MangaSourceException(
        '$name mengembalikan status ${response.statusCode}.',
      );
    }
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw MangaSourceException('Respons $name tidak sesuai format JSON.');
    }
  }

  Future<SourceMangaPage> _list({required int page, String? sort, String? query}) async {
    final url = Uri.parse('$_apiUrl/v1/manga/list').replace(queryParameters: {
      'page': '$page',
      'page_size': '30',
      'sort': ?sort,
      if (query != null && query.isNotEmpty) 'q': query,
    });
    final json = await _getJson(url);
    final data = (json['data'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final mangas = data
        .map((m) => SourceManga(
              url: m['manga_id'] as String? ?? '',
              title: m['title'] as String? ?? '',
              thumbnailUrl: m['cover_image_url'] as String?,
            ))
        .toList();
    final meta = json['meta'] as Map<String, dynamic>? ?? {};
    final currentPage = (meta['page'] as num?)?.toInt() ?? page;
    final totalPage = (meta['total_page'] as num?)?.toInt();
    final hasNextPage = totalPage != null && currentPage < totalPage;
    return SourceMangaPage(mangas: mangas, hasNextPage: hasNextPage);
  }

  @override
  Future<SourceMangaPage> fetchPopular(int page) =>
      _list(page: page, sort: 'popularity');

  @override
  Future<SourceMangaPage> fetchLatest(int page) =>
      _list(page: page, sort: 'latest');

  @override
  Future<SourceMangaPage> fetchSearch(String query, int page) =>
      _list(page: page, query: query);

  @override
  Future<SourceMangaDetails> fetchMangaDetails(String mangaUrl) async {
    final json =
        await _getJson(Uri.parse('$_apiUrl/v1/manga/detail/$mangaUrl'));
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final taxonomy = data['taxonomy'] as Map<String, dynamic>? ?? {};

    List<String> namesOf(String key) => (taxonomy[key] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map((e) => e['name'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    return SourceMangaDetails(
      description: data['description'] as String?,
      author: namesOf('Author').join(', ').ifEmptyNull(),
      artist: namesOf('Artist').join(', ').ifEmptyNull(),
      genres: [...namesOf('Genre'), ...namesOf('Format')],
      status: _statusOf((data['status'] as num?)?.toInt()),
    );
  }

  SourceMangaStatus _statusOf(int? status) => switch (status) {
        1 => SourceMangaStatus.ongoing,
        2 => SourceMangaStatus.completed,
        3 => SourceMangaStatus.hiatus,
        _ => SourceMangaStatus.unknown,
      };

  @override
  Future<List<SourceChapter>> fetchChapterList(String mangaUrl) async {
    final json = await _getJson(
      Uri.parse('$_apiUrl/v1/chapter/$mangaUrl/list')
          .replace(queryParameters: {'page_size': '3000'}),
    );
    final list =
        (json['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return list.map((c) {
      final number = (c['chapter_number'] as num?)?.toDouble() ?? 0;
      final numberLabel = number == number.roundToDouble()
          ? number.toInt().toString()
          : number.toString();
      final title = c['chapter_title'] as String? ?? '';
      final date = c['release_date'] as String?;
      return SourceChapter(
        url: c['chapter_id'] as String? ?? '',
        name: 'Chapter $numberLabel${title.isNotEmpty ? ' $title' : ''}',
        dateUpload: date == null ? null : DateTime.tryParse(date),
      );
    }).toList();
  }

  @override
  Future<List<SourcePage>> fetchPageList(String chapterUrl) async {
    final json =
        await _getJson(Uri.parse('$_apiUrl/v1/chapter/detail/$chapterUrl'));
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final chapterBaseUrl = data['base_url'] as String? ?? '';
    final chapter = data['chapter'] as Map<String, dynamic>? ?? {};
    final path = chapter['path'] as String? ?? '';
    final pages = (chapter['data'] as List<dynamic>? ?? []).cast<String>();
    return [
      for (var i = 0; i < pages.length; i++)
        SourcePage(index: i, imageUrl: '$chapterBaseUrl$path${pages[i]}'),
    ];
  }
}

extension _StringExt on String {
  String? ifEmptyNull() => isEmpty ? null : this;
}
