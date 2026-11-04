import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aplikasi_komik/sources/manga_source.dart';
import 'package:aplikasi_komik/sources/natsuid_source.dart';

/// Fixture meniru struktur WP REST API + fragment AJAX chapter_list tema
/// "NatsuId" (dipakai Ikiru) — lihat Dto.kt & NatsuId.kt di
/// keiyoushi/extensions-source.
void main() {
  late http.Client mockClient;
  late NatsuIdSource source;

  const mangaJson = {
    'id': 42,
    'slug': 'solo-leveling',
    'title': {'rendered': 'Solo Leveling'},
    'content': {'rendered': '<p>Cerita tentang pemburu terlemah.</p>'},
    '_embedded': {
      'wp:featuredmedia': [
        {'source_url': 'https://cdn.example/cover.jpg'},
      ],
      'wp:term': [
        [
          {'name': 'Chugong', 'slug': 'chugong', 'taxonomy': 'series-author'},
        ],
        [
          {'name': 'Action', 'slug': 'action', 'taxonomy': 'genre'},
          {'name': 'Fantasy', 'slug': 'fantasy', 'taxonomy': 'genre'},
        ],
        [
          {'name': 'Ongoing', 'slug': 'ongoing', 'taxonomy': 'status'},
        ],
      ],
    },
  };

  const chapterListFragment = '''
<div>
  <a href="/manga/solo-leveling/chapter-1/"><span>Chapter 1</span><time datetime="2024-01-15T10:30:00Z"></time></a>
  <a href="/manga/solo-leveling/chapter-2/"><span>Chapter 2</span><time datetime="2024-01-20T10:30:00Z"></time></a>
</div>
''';

  const pagesHtml = '''
<html><body>
<main><div class="relative"><section>
  <img src="https://cdn.example/pages/001.jpg">
  <img src="https://cdn.example/pages/002.jpg">
</section></div></main>
</body></html>
''';

  setUp(() {
    mockClient = MockClient((request) async {
      final path = request.url.path;
      final query = request.url.queryParameters;
      if (path == '/wp-json/wp/v2/manga') {
        return http.Response(
          jsonEncode([mangaJson]),
          200,
          headers: {'x-wp-totalpages': '3'},
        );
      }
      if (path == '/wp-json/wp/v2/manga/42') {
        return http.Response(jsonEncode(mangaJson), 200);
      }
      if (path == '/wp-admin/admin-ajax.php' &&
          query['action'] == 'chapter_list') {
        return http.Response(chapterListFragment, 200);
      }
      if (path == '/manga/solo-leveling/chapter-1/') {
        return http.Response(pagesHtml, 200);
      }
      return http.Response('not found', 404);
    });
    source = NatsuIdSource(
      name: 'Ikiru',
      baseUrl: 'https://ikiru.example',
      client: mockClient,
    );
  });

  test(
    'fetchPopular mengurai manga dari WP REST + hasNextPage dari header',
    () async {
      final result = await source.fetchPopular(1);
      expect(result.mangas, hasLength(1));
      expect(result.mangas.first.title, 'Solo Leveling');
      expect(result.mangas.first.thumbnailUrl, 'https://cdn.example/cover.jpg');
      expect(jsonDecode(result.mangas.first.url), {
        'id': 42,
        'slug': 'solo-leveling',
      });
      expect(result.hasNextPage, isTrue);
    },
  );

  test(
    'advanced_search membedakan urutan populer, terbaru, dan membawa nonce',
    () async {
      final requestedOrder = <String>[];
      final requestedQueries = <String>[];
      var nonceCalls = 0;
      final advancedClient = MockClient((request) async {
        if (request.url.path == '/wp-admin/admin-ajax.php' &&
            request.url.queryParameters['action'] == 'get_nonce') {
          nonceCalls++;
          return http.Response(
            '<input name="search_nonce" value="nonce-aman">',
            200,
          );
        }
        if (request.url.path == '/wp-admin/admin-ajax.php' &&
            request.url.queryParameters['action'] == 'advanced_search') {
          final order = _multipartField(request.body, 'orderby');
          requestedOrder.add(order ?? '');
          requestedQueries.add(_multipartField(request.body, 'query') ?? '');
          expect(_multipartField(request.body, 'nonce'), 'nonce-aman');
          final slugs = order == 'updated'
              ? ['latest-one', 'shared']
              : ['popular-one', 'shared'];
          return http.Response('''
<div><a href="/manga/${slugs[0]}/"><img src="/one.jpg"></a></div>
<div><a href="/manga/${slugs[1]}/"><img src="/two.jpg"></a></div>
<button><svg></svg></button>
''', 200);
        }
        if (request.url.path == '/wp-json/wp/v2/manga') {
          final slugs = request.url.queryParametersAll['slug[]'] ?? const [];
          return http.Response(
            ")]}'\n${jsonEncode([
              for (var i = slugs.length - 1; i >= 0; i--) {
                  'id': i + 1,
                  'slug': slugs[i],
                  'title': {'rendered': slugs[i]},
                  '_embedded': <String, Object?>{},
                },
            ])}",
            200,
          );
        }
        return http.Response('not found', 404);
      });
      final advanced = NatsuIdSource(
        name: 'Ikiru',
        baseUrl: 'https://ikiru.example',
        client: advancedClient,
      );

      final popular = await advanced.fetchPopular(1);
      final latest = await advanced.fetchLatest(1);
      final search = await advanced.fetchSearch('solo', 1);

      expect(popular.mangas.map((manga) => manga.title), [
        'popular-one',
        'shared',
      ]);
      expect(latest.mangas.map((manga) => manga.title), [
        'latest-one',
        'shared',
      ]);
      expect(popular.hasNextPage, isTrue);
      expect(requestedOrder, ['popular', 'updated', 'popular']);
      expect(requestedQueries, ['', '', 'solo']);
      expect(search.mangas, isNotEmpty);
      expect(nonceCalls, 1);
    },
  );

  test(
    'fetchMangaDetails mengurai deskripsi/author/genre/status dari _embedded',
    () async {
      final details = await source.fetchMangaDetails(
        jsonEncode({'id': 42, 'slug': 'solo-leveling'}),
      );
      expect(details.description, 'Cerita tentang pemburu terlemah.');
      expect(details.author, 'Chugong');
      expect(details.genres, ['Action', 'Fantasy']);
      expect(details.status, SourceMangaStatus.ongoing);
    },
  );

  test('fetchChapterList mengurai fragment AJAX chapter_list', () async {
    final chapters = await source.fetchChapterList(
      jsonEncode({'id': 42, 'slug': 'solo-leveling'}),
    );
    expect(chapters, hasLength(2));
    expect(chapters[0].name, 'Chapter 1');
    expect(
      chapters[0].url,
      'https://ikiru.example/manga/solo-leveling/chapter-1/',
    );
    expect(chapters[0].dateUpload, DateTime.utc(2024, 1, 15, 10, 30));
  });

  test('fetchPageList mengambil gambar dari halaman chapter', () async {
    final pages = await source.fetchPageList(
      'https://ikiru.example/manga/solo-leveling/chapter-1/',
    );
    expect(pages, hasLength(2));
    expect(pages[0].imageUrl, 'https://cdn.example/pages/001.jpg');
  });
}

String? _multipartField(String body, String name) => RegExp(
  'name="${RegExp.escape(name)}"\\r\\n\\r\\n([^\\r\\n]*)',
).firstMatch(body)?.group(1);
