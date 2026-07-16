import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aplikasi_komik/sources/manga_source.dart';
import 'package:aplikasi_komik/sources/mangathemesia_source.dart';

/// Fixture HTML minimal meniru struktur tema WordPress "MangaThemesia"
/// (dipakai Komikindo & ratusan situs sejenis) — lihat MangaThemesia.kt di
/// keiyoushi/extensions-source.
void main() {
  late http.Client mockClient;
  late MangaThemesiaSource source;

  http.Response html(String body) => http.Response(body, 200);

  const listHtml = '''
<html><body>
<div class="listupd">
  <div class="bs">
    <div class="bsx">
      <a href="/manga/solo-leveling/" title="Solo Leveling">
        <img data-lazy-src="https://cdn.example/cover1.jpg">
      </a>
    </div>
  </div>
  <div class="bs">
    <div class="bsx">
      <a href="/manga/tower-of-god/" title="Tower of God">
        <img src="https://cdn.example/cover2.jpg">
      </a>
    </div>
  </div>
</div>
<div class="pagination"><a class="next" href="?page=2">Next</a></div>
</body></html>
''';

  const detailHtml = '''
<html><body>
<div class="postbody">
  <div class="desc">Cerita tentang pemburu terlemah.</div>
  <div class="gnr"><a>Action</a><a>Fantasy</a></div>
  <div class="infomanga">
    <div itemprop="image"><img src="https://cdn.example/thumb.jpg"></div>
  </div>
  <table class="infotable">
    <tr><td>Author</td><td>Chugong</td></tr>
    <tr><td>Status</td><td>Ongoing</td></tr>
  </table>
</div>
<div id="chapterlist">
  <li><a href="/manga/solo-leveling/chapter-1/"><span class="chapternum">Chapter 1</span><span class="chapterdate">January 15, 2024</span></a></li>
  <li><a href="/manga/solo-leveling/chapter-2/"><span class="chapternum">Chapter 2</span><span class="chapterdate">January 20, 2024</span></a></li>
</div>
</body></html>
''';

  const pagesHtml = '''
<html><body>
<div id="readerarea">
  <img data-src="https://cdn.example/pages/001.jpg">
  <img src="https://cdn.example/pages/002.jpg">
</div>
</body></html>
''';

  setUp(() {
    mockClient = MockClient((request) async {
      final path = request.url.path;
      if (path == '/manga/') return html(listHtml);
      if (path == '/manga/solo-leveling/') return html(detailHtml);
      if (path == '/manga/solo-leveling/chapter-1/') return html(pagesHtml);
      return http.Response('not found', 404);
    });
    source = MangaThemesiaSource(
      name: 'Komikindo',
      baseUrl: 'https://komikindo.example',
      client: mockClient,
    );
  });

  test('fetchPopular mengurai kartu manga (dengan fallback lazy-src) & hasNextPage',
      () async {
    final result = await source.fetchPopular(1);
    expect(result.mangas, hasLength(2));
    expect(result.mangas.first.title, 'Solo Leveling');
    expect(result.mangas.first.url,
        'https://komikindo.example/manga/solo-leveling/');
    expect(result.mangas.first.thumbnailUrl, 'https://cdn.example/cover1.jpg');
    expect(result.hasNextPage, isTrue);
  });

  test('fetchMangaDetails mengurai desc/genre/author/status/thumbnail',
      () async {
    final details = await source
        .fetchMangaDetails('https://komikindo.example/manga/solo-leveling/');
    expect(details.description, 'Cerita tentang pemburu terlemah.');
    expect(details.genres, ['Action', 'Fantasy']);
    expect(details.author, 'Chugong');
    expect(details.status, SourceMangaStatus.ongoing);
    expect(details.thumbnailUrl, 'https://cdn.example/thumb.jpg');
  });

  test('fetchChapterList mengurai nama & tanggal "MMMM dd, yyyy"', () async {
    final chapters = await source
        .fetchChapterList('https://komikindo.example/manga/solo-leveling/');
    expect(chapters, hasLength(2));
    expect(chapters[0].name, 'Chapter 1');
    expect(chapters[0].dateUpload, DateTime(2024, 1, 15));
    expect(chapters[1].dateUpload, DateTime(2024, 1, 20));
  });

  test('fetchPageList mengambil gambar dengan fallback data-src', () async {
    final pages = await source.fetchPageList(
        'https://komikindo.example/manga/solo-leveling/chapter-1/');
    expect(pages, hasLength(2));
    expect(pages[0].imageUrl, 'https://cdn.example/pages/001.jpg');
    expect(pages[1].imageUrl, 'https://cdn.example/pages/002.jpg');
  });
}
