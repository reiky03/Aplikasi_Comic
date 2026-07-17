import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aplikasi_komik/sources/universal_html_source.dart';

void main() {
  late UniversalHtmlSource source;

  http.Response html(String body) => http.Response(body, 200);

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
  <li><a href="/series/ember-knight/chapter-2/">Chapter 2</a></li>
  <li><a href="/series/ember-knight/chapter-1/">Chapter 1</a></li>
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
