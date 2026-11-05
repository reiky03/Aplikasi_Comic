import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aplikasi_komik/sources/madara_source.dart';

void main() {
  test('archive Madara membedakan parameter populer dan terbaru', () async {
    final orders = <String>[];
    final source = MadaraSource(
      name: 'Madara Test',
      baseUrl: 'https://madara.example',
      client: MockClient((request) async {
        orders.add(request.url.queryParameters['m_orderby'] ?? '');
        final title = orders.last == 'latest'
            ? 'Latest Madara'
            : 'Popular Madara';
        return http.Response(_cardHtml(title, orders.last), 200);
      }),
    );

    final popular = await source.fetchPopular(1);
    final latest = await source.fetchLatest(1);

    expect(orders, ['views', 'latest']);
    expect(popular.mangas.single.title, 'Popular Madara');
    expect(latest.mangas.single.title, 'Latest Madara');
    expect(popular.mangas.single.thumbnailUrl, 'https://cdn.example/views.jpg');
  });

  test('halaman lanjut memakai madara_load_more setelah terdeteksi', () async {
    final requests = <String>[];
    final source = MadaraSource(
      name: 'Madara Test',
      baseUrl: 'https://madara.example',
      client: MockClient((request) async {
        if (request.method == 'GET') {
          requests.add('archive');
          return http.Response(
            '${_cardHtml('Page One', 'one')}<nav class="navigation-ajax"></nav>',
            200,
          );
        }
        requests.add(request.bodyFields['action'] ?? '');
        expect(request.bodyFields['page'], '1');
        expect(request.bodyFields['vars[meta_key]'], '_wp_manga_views');
        return http.Response(_cardHtml('Page Two', 'two'), 200);
      }),
    );

    await source.fetchPopular(1);
    final second = await source.fetchPopular(2);

    expect(requests, ['archive', 'madara_load_more']);
    expect(second.mangas.single.title, 'Page Two');
  });

  test(
    'chapter tersembunyi dan gambar dibaca lewat endpoint AJAX Madara',
    () async {
      final source = MadaraSource(
        name: 'Madara Test',
        baseUrl: 'https://madara.example',
        client: MockClient((request) async {
          if (request.method == 'GET' && request.url.path == '/manga/solo/') {
            return http.Response(
              '<div id="manga-chapters-holder-42" data-id="42"></div>',
              200,
            );
          }
          if (request.method == 'POST' &&
              request.url.path == '/wp-admin/admin-ajax.php') {
            expect(request.bodyFields['action'], 'manga_get_chapters');
            expect(request.bodyFields['manga'], '42');
            return http.Response('''
<ul><li class="wp-manga-chapter">
  <a href="/manga/solo/chapter-7/">Chapter 7</a>
  <span class="chapter-release-date">2 hours ago</span>
</li></ul>
''', 200);
          }
          if (request.method == 'GET' &&
              request.url.path == '/manga/solo/chapter-7/') {
            return http.Response('''
<div class="reading-content">
  <div class="page-break"><img data-src="https://cdn.example/001.jpg"></div>
  <div class="page-break"><img data-src="https://cdn.example/002.jpg"></div>
</div>
''', 200);
          }
          return http.Response('not found', 404);
        }),
      );

      final chapters = await source.fetchChapterList(
        'https://madara.example/manga/solo/',
      );
      final pages = await source.fetchPageList(chapters.single.url);

      expect(chapters.single.name, 'Chapter 7');
      expect(chapters.single.dateUpload, isNotNull);
      expect(pages, hasLength(2));
      expect(pages.first.imageUrl, 'https://cdn.example/001.jpg');
      expect(pages.first.headers['Referer'], chapters.single.url);
    },
  );

  test('MadaraSource dengan domain toongod memakai path /webtoons/', () async {
    final paths = <String>[];
    final source = MadaraSource(
      name: 'ToonGod',
      baseUrl: 'https://www.toongod.org/webtoons',
      client: MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(_cardHtml('Solo Leveling', 'solo'), 200);
      }),
    );

    await source.fetchPopular(1);
    await source.fetchPopular(2);

    expect(paths, ['/webtoons/', '/webtoons/page/2/']);
  });
}

String _cardHtml(String title, String slug) =>
    '''
<div class="page-item-detail manga">
  <div class="post-title"><a href="/manga/$slug/">$title</a></div>
  <img data-src="https://cdn.example/$slug.jpg">
</div>
<div class="nav-previous"></div>
''';
