import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aplikasi_komik/sources/imhentai_source.dart';
import 'package:aplikasi_komik/sources/manga_source.dart';
import 'package:aplikasi_komik/sources/source_catalog.dart';

const _mockCatalogHtml = '''
<!DOCTYPE html>
<html>
<body>
  <div class="thumb">
    <div class="inner_thumb">
      <a href="/gallery/123456/">
        <img data-src="https://m1.imhentai.xxx/012/123456/thumb.jpg" />
      </a>
    </div>
    <div class="caption">
      <a href="/gallery/123456/">Manga Sample 1</a>
    </div>
  </div>
  <div class="thumb">
    <div class="inner_thumb">
      <a href="/gallery/789012/">
        <img src="https://m2.imhentai.xxx/078/789012/thumb.jpg" />
      </a>
    </div>
    <div class="caption">
      <a href="/gallery/789012/">Manga Sample 2</a>
    </div>
  </div>
  <ul class="pagination">
    <li class="active"><span>1</span></li>
    <li><a href="/popular/?page=2">2</a></li>
  </ul>
</body>
</html>
''';

const _mockDetailsHtml = '''
<!DOCTYPE html>
<html>
<body>
  <div class="left_cover">
    <img data-src="https://m1.imhentai.xxx/012/123456/cover.jpg" />
  </div>
  <h1>Manga Sample Title</h1>
  <p class="subtitle">Sample Subtitle</p>
  <ul>
    <li>
      <span class="tags_text">Artists:</span>
      <a class="tag" href="/artist/cool-artist/">Cool Artist</a>
    </li>
    <li>
      <span class="tags_text">Tags:</span>
      <a class="tag" href="/tag/romance/">Romance</a>
      <a class="tag" href="/tag/comedy/">Comedy</a>
    </li>
  </ul>
  <span class="uploaded">2 days ago</span>
  <input type="hidden" id="load_server" value="3" />
  <input type="hidden" id="load_dir" value="012" />
  <input type="hidden" id="load_id" value="123456" />
  <input type="hidden" id="load_pages" value="3" />
  <script>
    var g_th = \$.parseJSON('{"1":"j,1100,1148","2":"p,1100,1148","3":"w,1100,1148"}');
  </script>
</body>
</html>
''';

const _mockDetailsFallbackHtml = '''
<!DOCTYPE html>
<html>
<body>
  <h1>Manga Fallback</h1>
  <div class="cover">
    <img src="https://m1.imhentai.xxx/012/999/cover.jpg" />
  </div>
  <input type="hidden" id="load_server" value="1" />
  <input type="hidden" id="load_dir" value="012" />
  <input type="hidden" id="load_id" value="999" />
  <input type="hidden" id="load_pages" value="2" />
  <div class="gthumb">
    <img data-src="https://m1.imhentai.xxx/012/999/1t.jpg" />
    <img data-src="https://m1.imhentai.xxx/012/999/2t.jpg" />
  </div>
</body>
</html>
''';

void main() {
  group('ImhentaiSource Tests', () {
    late ImhentaiSource source;
    late List<Uri> requestedUris;

    setUp(() {
      requestedUris = [];
      source = ImhentaiSource(
        client: MockClient((request) async {
          requestedUris.add(request.url);
          final path = request.url.path;

          if (request.url.queryParameters['page'] == '999') {
            return http.Response('Just a moment... Cloudflare Turnstile', 403);
          }

          if (path == '/popular/' || path == '/' || path == '/search/') {
            return http.Response(_mockCatalogHtml, 200);
          }

          if (path == '/gallery/123456/') {
            return http.Response(_mockDetailsHtml, 200);
          }

          if (path == '/gallery/999/') {
            return http.Response(_mockDetailsFallbackHtml, 200);
          }

          if (path == '/blocked/') {
            return http.Response('Just a moment... Cloudflare Turnstile', 403);
          }

          return http.Response('Not Found', 404);
        }),
      );
    });

    test('fetchPopular mem-parse daftar komik dan pagination dengan benar', () async {
      final page = await source.fetchPopular(1);
      expect(page.mangas.length, 2);
      expect(page.hasNextPage, isTrue);

      final first = page.mangas.first;
      expect(first.title, 'Manga Sample 1');
      expect(first.url, 'https://imhentai.xxx/gallery/123456/');
      expect(first.thumbnailUrl, 'https://m1.imhentai.xxx/012/123456/thumb.jpg');

      final second = page.mangas[1];
      expect(second.title, 'Manga Sample 2');
      expect(second.thumbnailUrl, 'https://m2.imhentai.xxx/078/789012/thumb.jpg');
    });

    test('fetchLatest dan fetchSearch memanggil endpoint yang tepat', () async {
      final latest = await source.fetchLatest(1);
      expect(latest.mangas.length, 2);
      expect(requestedUris.last.path, '/');

      final search = await source.fetchSearch('test keyword', 1);
      expect(search.mangas.length, 2);
      expect(requestedUris.last.path, '/search/');
      expect(requestedUris.last.queryParameters['key'], 'test keyword');
    });

    test('fetchMangaDetails mengekstrak info galeri dengan benar', () async {
      final details = await source.fetchMangaDetails('https://imhentai.xxx/gallery/123456/');
      expect(details.author, 'Cool Artist');
      expect(details.genres, contains('Romance'));
      expect(details.genres, contains('Comedy'));
      expect(details.thumbnailUrl, 'https://m1.imhentai.xxx/012/123456/cover.jpg');
      expect(details.description, contains('Pages: 3'));
      expect(details.description, contains('Subtitle: Sample Subtitle'));
      expect(details.status, SourceMangaStatus.completed);
    });

    test('fetchChapterList mengembalikan 1 chapter single-gallery', () async {
      final chapters = await source.fetchChapterList('https://imhentai.xxx/gallery/123456/');
      expect(chapters.length, 1);
      expect(chapters.first.name, 'Full Gallery');
      expect(chapters.first.url, 'https://imhentai.xxx/gallery/123456/');
    });

    test('fetchPageList mem-parse JSON embedded metadata (load_server, load_id, ext)', () async {
      final pages = await source.fetchPageList('https://imhentai.xxx/gallery/123456/');
      expect(pages.length, 3);

      expect(pages[0].index, 0);
      expect(pages[0].imageUrl, 'https://m3.imhentai.xxx/012/123456/1.jpg');

      expect(pages[1].index, 1);
      expect(pages[1].imageUrl, 'https://m3.imhentai.xxx/012/123456/2.png');

      expect(pages[2].index, 2);
      expect(pages[2].imageUrl, 'https://m3.imhentai.xxx/012/123456/3.webp');
    });

    test('fetchPageList mendukung fallback thumbnail stripping', () async {
      final pages = await source.fetchPageList('https://imhentai.xxx/gallery/999/');
      expect(pages.length, 2);
      expect(pages[0].imageUrl, 'https://m1.imhentai.xxx/012/999/1.jpg');
      expect(pages[1].imageUrl, 'https://m1.imhentai.xxx/012/999/2.jpg');
    });

    test('Cloudflare 403 melempar MangaSourceWebViewException', () async {
      expect(
        () => source.fetchPopular(999).catchError((e) {
          throw e;
        }),
        throwsA(isA<MangaSourceWebViewException>()),
      );
    });

    test('SourceCatalog mengenali imhentai.xxx dan mengembalikan ImhentaiSource', () {
      final src = SourceCatalog.buildGeneric(
        'imhentai',
        'IMHentai',
        'https://imhentai.xxx',
      );
      expect(src, isA<ImhentaiSource>());

      final srcMirror = SourceCatalog.buildGeneric(
        'extension-runtime:eu.kanade.tachiyomi.extension.all.imhentai',
        'Any',
        'https://imhentai.com',
      );
      expect(srcMirror, isA<ImhentaiSource>());

      final auto = SourceCatalog.buildAutomatic('IMHentai', 'https://imhentai.xxx');
      expect(auto, isA<ImhentaiSource>());
    });
  });
}
