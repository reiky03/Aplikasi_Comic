import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aplikasi_komik/sources/sveltekit_comic_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const listHtml = '''
<html><body>
<script type="application/json" data-sveltekit-fetched>
{"hot_weekly":[{"title":"Soul Knight","slug":"soul-knight",
"poster_image_url":"https://img.soulscans.asia/covers/soul.webp",
"comic_status":"ONGOING"}]}
</script>
<a href="/comic/soul-knight"><img alt="Soul Knight" src="https://img.soulscans.asia/covers/soul.webp"></a>
</body></html>
''';

  const detailHtml = '''
<html><head>
<meta name="description" content="A knight survives the broken world.">
<meta property="og:image" content="https://img.soulscans.asia/covers/soul.webp">
</head><body>
<script type="application/json" data-sveltekit-fetched>
{"comic_status":"ONGOING","chapters":[{"slug":"chapter-2","title":"Chapter 2"}]}
</script>
<a href="/comic/soul-knight/chapter/chapter-2">First chapter</a>
</body></html>
''';

  const pagesHtml = '''
<html><body><main>
<img src="http://sscdn.dbm.my.id/extracts/soul/00.webp">
<img src="http://sscdn.dbm.my.id/extracts/soul/01.webp">
</main>
<script type="application/json" data-sveltekit-fetched>
{"pages":[{"image_url":"http://sscdn.dbm.my.id/extracts/soul/02.webp"}]}
</script>
</body></html>
''';

  late SvelteKitComicSource source;
  setUp(() {
    source = SvelteKitComicSource(
      name: 'Soul Scans',
      baseUrl: 'https://v1.soulscans.asia',
      client: MockClient((request) async {
        switch (request.url.path) {
          case '/':
          case '/comic':
          case '/allcomic':
            return http.Response(listHtml, 200);
          case '/comic/soul-knight':
            return http.Response(detailHtml, 200);
          case '/comic/soul-knight/chapter/chapter-2':
            return http.Response(pagesHtml, 200);
          default:
            return http.Response('not found', 404);
        }
      }),
    );
  });

  test('membaca daftar manga dari payload SvelteKit', () async {
    final page = await source.fetchPopular(1);

    expect(page.mangas.single.title, 'Soul Knight');
    expect(
      page.mangas.single.url,
      'https://v1.soulscans.asia/comic/soul-knight',
    );
    expect(page.mangas.single.thumbnailUrl, contains('soul.webp'));
  });

  test('popular meminta sorting resmi dari endpoint API', () async {
    final requestedPaths = <String>[];
    final catalogSource = SvelteKitComicSource(
      name: 'Soul Scans',
      baseUrl: 'https://v1.soulscans.asia',
      client: MockClient((request) async {
        requestedPaths.add(request.url.path);
        if (request.url.path == '/api/search') {
          expect(request.url.queryParameters['sort'], 'popular');
          expect(request.url.queryParameters['order'], 'desc');
        }
        return http.Response(listHtml, 200);
      }),
    );

    await catalogSource.fetchPopular(1);

    expect(requestedPaths.first, '/api/search');
    expect(requestedPaths, contains('/'));
  });

  test(
    'latest juga memakai katalog penuh saat route latest tidak ada',
    () async {
      final requestedPaths = <String>[];
      final latestSource = SvelteKitComicSource(
        name: 'Soul Scans',
        baseUrl: 'https://v1.soulscans.asia',
        client: MockClient((request) async {
          requestedPaths.add(request.url.path);
          expect(request.url.queryParameters['sort'], 'latest');
          expect(request.url.queryParameters['order'], 'desc');
          return http.Response(listHtml, 200);
        }),
      );

      await latestSource.fetchLatest(1);

      expect(requestedPaths, contains('/api/search'));
      expect(requestedPaths, contains('/allcomic'));
    },
  );

  test('latest memakai endpoint API resmi saat tersedia', () async {
    final apiSource = SvelteKitComicSource(
      name: 'Soul Scans',
      baseUrl: 'https://v1.soulscans.asia',
      client: MockClient((request) async {
        expect(request.url.path, '/api/search');
        expect(request.url.queryParameters, {
          'type': 'COMIC',
          'limit': '50',
          'page': '1',
          'sort': 'latest',
          'order': 'desc',
        });
        return http.Response(
          jsonEncode({
            'data': [
              {
                'title': 'Fresh Manga',
                'slug': 'fresh-manga',
                'poster_image_url':
                    'https://img.soulscans.asia/covers/fresh.webp',
              },
            ],
          }),
          200,
        );
      }),
    );

    final page = await apiSource.fetchLatest(1);

    expect(page.mangas.single.title, 'Fresh Manga');
  });

  test('membaca detail dan chapter dari route SvelteKit', () async {
    final detail = await source.fetchMangaDetails(
      'https://v1.soulscans.asia/comic/soul-knight',
    );
    final chapters = await source.fetchChapterList(
      'https://v1.soulscans.asia/comic/soul-knight',
    );

    expect(detail.description, contains('knight survives'));
    expect(detail.status.name, 'ongoing');
    expect(chapters.single.name, 'Chapter 2');
  });

  test('mengubah URL gambar HTTP Soulscans menjadi HTTPS', () async {
    final pages = await source.fetchPageList(
      'https://v1.soulscans.asia/comic/soul-knight/chapter/chapter-2',
    );

    expect(pages, hasLength(3));
    expect(pages.first.imageUrl, startsWith('https://sscdn.dbm.my.id/'));
    expect(pages.first.headers['Referer'], contains('chapter-2'));
  });
}
