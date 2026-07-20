import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aplikasi_komik/data/extension_runtime.dart';
import 'package:aplikasi_komik/sources/universal_html_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UniversalHtmlSource source;
  const channel = MethodChannel('kizen/extension_runtime');

  http.Response html(String body) => http.Response(body, 200);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  const listHtml = '''
<html><body>
<div class="manga__item">
  <a href="/series/ember-knight/" title="Ember Knight">
    <img data-src="https://cdn.example/ember.webp">
  </a>
</div>
<a class="next" href="/manga/page/2/">Next</a>
</body></html>
''';

  const detailHtml = '''
<html><body>
<div class="summary_image"><img src="https://cdn.example/ember-cover.webp"></div>
<div class="summary__content">A knight survives with wit instead of strength.</div>
<div class="genres"><a>Action</a><a>Fantasy</a></div>
<ul class="chapter-list">
  <li class="wp-manga-chapter">
    <a href="/series/ember-knight/chapter-2/">Chapter 2</a>
    <span class="chapter-release-date"><i>20 Jul 2026</i></span>
  </li>
  <li class="wp-manga-chapter">
    <a href="/series/ember-knight/chapter-1/">Chapter 1</a>
    <span class="chapter-release-date"><i>19/07/2026</i></span>
  </li>
</ul>
</body></html>
''';

  const pagesHtml = '''
<html><body>
<div class="reading-content">
  <img data-original="https://cdn.example/pages/001.webp">
  <img src="https://cdn.example/pages/002.webp">
</div>
</body></html>
''';

  setUp(() {
    source = UniversalHtmlSource(
      name: 'Generic',
      baseUrl: 'https://generic.example',
      client: MockClient((request) async {
        final path = request.url.path;
        if (path == '/manga/') return html(listHtml);
        if (path == '/series/ember-knight/') return html(detailHtml);
        if (path == '/series/ember-knight/chapter-2/') return html(pagesHtml);
        return http.Response('not found', 404);
      }),
    );
  });

  test('fetchPopular mengurai kartu komik generic', () async {
    final page = await source.fetchPopular(1);
    expect(page.mangas, hasLength(1));
    expect(page.mangas.first.title, 'Ember Knight');
    expect(
      page.mangas.first.url,
      'https://generic.example/series/ember-knight/',
    );
    expect(page.hasNextPage, isTrue);
  });

  test('fetchPopular mencoba katalog Toongod /webtoons lebih dulu', () async {
    final requestedUrls = <Uri>[];
    final toongodSource = UniversalHtmlSource(
      name: 'Toongod',
      baseUrl: 'https://www.toongod.org/webtoons/',
      client: MockClient((request) async {
        requestedUrls.add(request.url);
        if (request.url.path == '/webtoons/') {
          return html('''
<html><body>
<div class="manga__item">
  <a href="/webtoons/ember-knight/" title="Ember Knight">
    <img data-src="https://www.toongod.org/wp-content/uploads/ember.webp">
  </a>
</div>
<a class="nextpostslink" href="/webtoons/page/2/">Next</a>
</body></html>
''');
        }
        return http.Response('not found', 404);
      }),
    );

    final page = await toongodSource.fetchPopular(1);

    expect(page.mangas.single.title, 'Ember Knight');
    expect(
      page.mangas.single.thumbnailUrl,
      'https://i0.wp.com/www.toongod.org/wp-content/uploads/ember.webp',
    );
    expect(page.mangas.single.headers, isEmpty);
    expect(page.hasNextPage, isTrue);
    expect(requestedUrls.single.path, '/webtoons/');
    expect(requestedUrls.single.queryParameters['m_orderby'], 'trending');
  });

  test('Toongod terbaru dan halaman berikutnya memakai URL berbeda', () async {
    final requestedUrls = <Uri>[];
    final toongodSource = UniversalHtmlSource(
      name: 'Toongod',
      baseUrl: 'https://www.toongod.org/webtoons/',
      client: MockClient((request) async {
        requestedUrls.add(request.url);
        return html('''
<html><body>
<div class="page-item-detail">
  <a href="/webtoon/page-${request.url.pathSegments.length}/" title="Page Item">
    <img data-src="https://www.toongod.org/wp-content/uploads/item.jpg">
  </a>
</div>
</body></html>
''');
      }),
    );

    await toongodSource.fetchLatest(1);
    await toongodSource.fetchPopular(2);

    expect(requestedUrls[0].path, '/webtoons/');
    expect(requestedUrls[0].queryParameters['m_orderby'], 'latest');
    expect(requestedUrls[1].path, '/webtoons/page/2/');
    expect(requestedUrls[1].queryParameters['m_orderby'], 'trending');
  });

  test('fetchMangaDetails mengurai detail umum', () async {
    final detail = await source.fetchMangaDetails(
      'https://generic.example/series/ember-knight/',
    );
    expect(detail.description, contains('knight survives'));
    expect(detail.genres, ['Action', 'Fantasy']);
    expect(detail.thumbnailUrl, 'https://cdn.example/ember-cover.webp');
  });

  test('fetchChapterList mengurai link chapter umum', () async {
    final chapters = await source.fetchChapterList(
      'https://generic.example/series/ember-knight/',
    );
    expect(chapters, hasLength(2));
    expect(chapters.first.name, 'Chapter 2');
    expect(chapters.first.dateUpload, DateTime(2026, 7, 20));
    expect(chapters.last.dateUpload, DateTime(2026, 7, 19));
  });

  test('fetchPageList mengurai gambar reader umum', () async {
    final pages = await source.fetchPageList(
      'https://generic.example/series/ember-knight/chapter-2/',
    );
    expect(pages, hasLength(2));
    expect(pages.first.imageUrl, 'https://cdn.example/pages/001.webp');
    expect(
      pages.first.headers['Referer'],
      'https://generic.example/series/ember-knight/chapter-2/',
    );
  });

  test('fetchPageList menerima URL chapter relatif dari extension', () async {
    final pages = await source.fetchPageList('/series/ember-knight/chapter-2/');

    expect(pages, hasLength(2));
    expect(pages.first.imageUrl, 'https://cdn.example/pages/001.webp');
    expect(
      pages.first.headers['Referer'],
      'https://generic.example/series/ember-knight/chapter-2/',
    );
  });

  test('fetchPopular mengurai daftar komik dari Next.js JSON', () async {
    final nextSource = UniversalHtmlSource(
      name: 'Next Source',
      baseUrl: 'https://next.example',
      client: MockClient(
        (_) async => html('''
<html><body>
<script id="__NEXT_DATA__" type="application/json">
{"props":{"pageProps":{"mangas":[
  {"title":"Night Code","slug":"night-code",
   "cover":{"url":"https://cdn.example/image?id=42"}}
]}}}
</script>
</body></html>
'''),
      ),
    );

    final page = await nextSource.fetchPopular(1);

    expect(page.mangas, hasLength(1));
    expect(page.mangas.first.title, 'Night Code');
    expect(page.mangas.first.url, 'https://next.example/manga/night-code/');
    expect(page.mangas.first.thumbnailUrl, 'https://cdn.example/image?id=42');
  });

  test('fetchPageList mengurai URL gambar dari JSON embedded', () async {
    final jsonSource = UniversalHtmlSource(
      name: 'JSON Reader',
      baseUrl: 'https://json.example',
      client: MockClient(
        (_) async => html(r'''
<html><body>
<script type="application/json">
{"pages":[
  {"src":"https:\/\/cdn.example\/reader\/001.webp"},
  {"src":"https:\/\/cdn.example\/reader\/002.webp"}
]}
</script>
</body></html>
'''),
      ),
    );

    final pages = await jsonSource.fetchPageList(
      'https://json.example/chapter/1',
    );

    expect(pages, hasLength(2));
    expect(pages.first.imageUrl, 'https://cdn.example/reader/001.webp');
  });

  test('fetchPageList membaca source srcset dan preload image', () async {
    final pictureSource = UniversalHtmlSource(
      name: 'Picture Reader',
      baseUrl: 'https://picture.example',
      client: MockClient(
        (_) async => html('''
<html><head>
<link rel="preload" as="image" href="https://cdn.example/preload-001.webp">
</head><body>
<picture>
  <source srcset="https://cdn.example/picture-002.webp 1x">
</picture>
</body></html>
'''),
      ),
    );

    final pages = await pictureSource.fetchPageList(
      'https://picture.example/read/1',
    );

    expect(pages.map((page) => page.imageUrl), [
      'https://cdn.example/preload-001.webp',
      'https://cdn.example/picture-002.webp',
    ]);
  });

  test('fetchPageList membaca JSON string dan URL gambar relatif', () async {
    final relativeSource = UniversalHtmlSource(
      name: 'Relative Reader',
      baseUrl: 'https://relative.example',
      client: MockClient(
        (_) async => html(r'''
<html><body>
<script type="application/json">
{
  "payload": "[{\"src\":\"\\/uploads\\/reader\\/001.jpg\"}]"
}
</script>
<script>
window.pages = ["\/wp-content\/uploads\/reader\/002.webp"];
</script>
</body></html>
'''),
      ),
    );

    final pages = await relativeSource.fetchPageList(
      'https://relative.example/read/1',
    );

    expect(pages.map((page) => page.imageUrl), [
      'https://relative.example/uploads/reader/001.jpg',
      'https://relative.example/wp-content/uploads/reader/002.webp',
    ]);
  });

  test('fetchPopular fallback ke API JSON umum', () async {
    final apiSource = UniversalHtmlSource(
      name: 'API Source',
      baseUrl: 'https://api-reader.example',
      client: MockClient((request) async {
        if (request.url.path == '/wp-json/wp/v2/manga') {
          return http.Response(
            '''
[
  {
    "title":{"rendered":"API Knight"},
    "link":"https://api-reader.example/manga/api-knight/",
    "jetpack_featured_media_url":"https://cdn.example/covers/api.webp"
  }
]
''',
            200,
            headers: {'x-wp-totalpages': '1'},
          );
        }
        return http.Response('not found', 404);
      }),
    );

    final page = await apiSource.fetchPopular(1);

    expect(page.mangas, hasLength(1));
    expect(page.mangas.first.title, 'API Knight');
    expect(page.mangas.first.thumbnailUrl, contains('api.webp'));
    expect(page.hasNextPage, isFalse);
  });

  test(
    'fetchPopular memakai DOM hasil WebView saat HTML awal kosong',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'renderHtmlWithWebView');
            return '''
<html><body>
<div class="manga__item">
  <a href="/series/rendered/" title="Rendered Knight">
    <img src="https://cdn.example/rendered.webp">
  </a>
</div>
</body></html>
''';
          });
      final renderedSource = UniversalHtmlSource(
        name: 'Rendered Source',
        baseUrl: 'https://rendered.example',
        bridge: const ExtensionRuntimeBridge(channel: channel),
        client: MockClient(
          (_) async => html('<html><body><div id="app"></div></body></html>'),
        ),
      );

      final page = await renderedSource.fetchPopular(1);

      expect(page.mangas.single.title, 'Rendered Knight');
      expect(
        page.mangas.single.url,
        'https://rendered.example/series/rendered/',
      );
    },
    skip: 'WebView otomatis dimatikan sementara untuk safe mode ANR.',
  );

  test(
    'fetchPopular membaca state JavaScript dari snapshot WebView',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'renderHtmlWithWebView');
            return '''
<html><body><div id="app"></div></body></html>
<script id="kizen-webview-state" type="application/json">
{
  "kizenSnapshot": true,
  "globals": {
    "__NUXT__": {
      "data": [
        {
          "series": [
            {
              "title": "State Knight",
              "slug": "state-knight",
              "cover_url": "https://cdn.example/state.webp"
            }
          ]
        }
      ]
    }
  }
}
</script>
''';
          });
      final renderedSource = UniversalHtmlSource(
        name: 'State Source',
        baseUrl: 'https://state.example',
        bridge: const ExtensionRuntimeBridge(channel: channel),
        client: MockClient(
          (_) async => html('<html><body><div id="app"></div></body></html>'),
        ),
      );

      final page = await renderedSource.fetchPopular(1);

      expect(page.mangas.single.title, 'State Knight');
      expect(
        page.mangas.single.url,
        'https://state.example/manga/state-knight/',
      );
      expect(page.mangas.single.thumbnailUrl, 'https://cdn.example/state.webp');
    },
    skip: 'WebView snapshot otomatis dimatikan sementara untuk safe mode ANR.',
  );

  test(
    'fetchPopular membaca payload API dari network snapshot WebView',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'renderHtmlWithWebView');
            return '''
<html><body><div id="app"></div></body></html>
<script id="kizen-webview-network" type="application/json">
{
  "kizenNetworkSnapshot": true,
  "responses": [
    {
      "data": [
        {
          "title": "Captured API",
          "slug": "captured-api",
          "cover_url": "https://cdn.example/captured.webp"
        }
      ]
    }
  ]
}
</script>
''';
          });
      final renderedSource = UniversalHtmlSource(
        name: 'Captured Source',
        baseUrl: 'https://captured.example',
        bridge: const ExtensionRuntimeBridge(channel: channel),
        client: MockClient(
          (_) async => html('<html><body><div id="app"></div></body></html>'),
        ),
      );

      final page = await renderedSource.fetchPopular(1);

      expect(page.mangas.single.title, 'Captured API');
      expect(
        page.mangas.single.url,
        'https://captured.example/manga/captured-api/',
      );
    },
    skip: 'WebView network snapshot dimatikan sementara untuk safe mode ANR.',
  );

  test('fetchPopular mengenali cover b2key dari API Comick-like', () async {
    final comickLike = UniversalHtmlSource(
      name: 'ComickLike',
      baseUrl: 'https://comick.example',
      client: MockClient(
        (_) async => html('''
<html><body>
<script type="application/json">
{
  "data": [
    {
      "title": "B2 Cover",
      "slug": "b2-cover",
      "b2key": "covers/b2-cover.webp"
    }
  ]
}
</script>
</body></html>
'''),
      ),
    );

    final page = await comickLike.fetchPopular(1);

    expect(
      page.mangas.single.thumbnailUrl,
      'https://meo.comick.pictures/covers/b2-cover.webp',
    );
  });

  test('fetchPopular mencoba API HeanCms di subdomain api', () async {
    final heanSource = UniversalHtmlSource(
      name: 'HeanLike',
      baseUrl: 'https://hean.example',
      client: MockClient((request) async {
        if (request.url.host == 'api.hean.example' &&
            request.url.path == '/query') {
          return http.Response('''
{
  "data": [
    {
      "id": 77,
      "series_slug": "api-dragon",
      "title": "API Dragon",
      "thumbnail": "https://cdn.example/covers/dragon.webp",
      "status": "Ongoing"
    }
  ],
  "meta": {"current_page": 1, "last_page": 3}
}
''', 200);
        }
        return http.Response('not found', 404);
      }),
    );

    final page = await heanSource.fetchPopular(1);

    expect(page.mangas, hasLength(1));
    expect(page.mangas.first.title, 'API Dragon');
    expect(page.mangas.first.url, 'https://hean.example/series/api-dragon#77');
    expect(page.hasNextPage, isTrue);
  });

  test('chapter dan page mencoba API HeanCms saat HTML kosong', () async {
    final heanSource = UniversalHtmlSource(
      name: 'HeanReader',
      baseUrl: 'https://hean-reader.example',
      client: MockClient((request) async {
        if (request.url.host == 'hean-reader.example' &&
            request.url.path == '/series/api-dragon') {
          return html('<html><body><main></main></body></html>');
        }
        if (request.url.host == 'api.hean-reader.example' &&
            request.url.path == '/chapter/query') {
          return http.Response('''
{
  "data": [
    {
      "id": 9,
      "chapter_name": "Chapter 9",
      "chapter_slug": "chapter-9",
      "price": 0
    }
  ],
  "meta": {"current_page": 1, "last_page": 1}
}
''', 200);
        }
        if (request.url.host == 'hean-reader.example' &&
            request.url.path == '/series/api-dragon/chapter-9') {
          return html('<html><body><main></main></body></html>');
        }
        if (request.url.host == 'api.hean-reader.example' &&
            request.url.path == '/chapter/api-dragon/chapter-9') {
          return http.Response('''
{"chapter":{"chapter_data":{"images":[
  "https://cdn.example/pages/009-1.webp",
  "https://cdn.example/pages/009-2.webp"
]}}}
''', 200);
        }
        return http.Response('not found', 404);
      }),
    );

    final chapters = await heanSource.fetchChapterList(
      'https://hean-reader.example/series/api-dragon#77',
    );
    final pages = await heanSource.fetchPageList(chapters.first.url);

    expect(chapters, hasLength(1));
    expect(chapters.first.url, contains('/series/api-dragon/chapter-9#9'));
    expect(pages, hasLength(2));
    expect(pages.first.imageUrl, 'https://cdn.example/pages/009-1.webp');
  });

  test('fetchPopular membaca JSON dari script inline Nuxt', () async {
    final nuxtSource = UniversalHtmlSource(
      name: 'Nuxt',
      baseUrl: 'https://nuxt.example',
      client: MockClient(
        (_) async => html(r'''
<html><body>
<script>
window.__NUXT__={"state":{"series":[
  {"title":"Nuxt Star","slug":"nuxt-star","cover_url":"https:\/\/cdn.example\/nuxt.webp"}
]}};
</script>
</body></html>
'''),
      ),
    );

    final page = await nuxtSource.fetchPopular(1);

    expect(page.mangas, hasLength(1));
    expect(page.mangas.first.title, 'Nuxt Star');
    expect(page.mangas.first.thumbnailUrl, 'https://cdn.example/nuxt.webp');
  });

  test('detail dan chapter dapat dibaca dari JSON aplikasi modern', () async {
    const modernHtml = r'''
<html><body>
<script id="__NEXT_DATA__" type="application/json">
{
  "props":{"pageProps":{"series":{
    "title":"JSON Knight",
    "description":"A sufficiently long description stored in application JSON.",
    "author":{"name":"A. Writer"},
    "genres":[{"name":"Action"},{"name":"Fantasy"}],
    "cover":"https:\/\/cdn.example\/covers\/json.webp",
    "chapters":[
      {"name":"Chapter 2","url":"\/manga\/json-knight\/chapter-2\/"},
      {"name":"Chapter 1","url":"\/manga\/json-knight\/chapter-1\/"}
    ]
  }}}
}
</script>
</body></html>
''';
    final modernSource = UniversalHtmlSource(
      name: 'Modern',
      baseUrl: 'https://modern.example',
      client: MockClient((_) async => html(modernHtml)),
    );

    final detail = await modernSource.fetchMangaDetails(
      'https://modern.example/manga/json-knight/',
    );
    final chapters = await modernSource.fetchChapterList(
      'https://modern.example/manga/json-knight/',
    );

    expect(detail.description, contains('application JSON'));
    expect(detail.author, 'A. Writer');
    expect(detail.genres, containsAll(['Action', 'Fantasy']));
    expect(chapters, hasLength(2));
    expect(chapters.first.name, 'Chapter 2');
  });
}
