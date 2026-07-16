import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aplikasi_komik/sources/komiku_source.dart';
import 'package:aplikasi_komik/sources/manga_source.dart';

/// Fixture HTML minimal meniru struktur asli komiku.org (lihat Komiku.kt
/// di keiyoushi/extensions-source) — dipakai supaya parsing tervalidasi
/// tanpa perlu akses internet asli.
void main() {
  late http.Client mockClient;
  late KomikuSource source;

  http.Response html(String body) => http.Response(body, 200);

  const listHtml = '''
<html><body>
<div class="bge">
  <a href="/manga/solo-leveling/"><h3>Solo Leveling</h3></a>
  <img src="https://cdn.komiku.org/cover1.jpg?v=1">
</div>
<div class="bge">
  <a href="/manga/tower-of-god/"><h3>Tower of God</h3></a>
  <img src="https://cdn.komiku.org/cover2.jpg">
</div>
<span hx-get="/more"></span>
</body></html>
''';

  // Detail & daftar chapter ada di halaman yang sama di Komiku asli
  // (chapterListRequest = GET ulang ke manga.url yang sama).
  const detailHtml = '''
<html><body>
<div id="Sinopsis"><p>Cerita tentang pemburu terlemah.</p></div>
<table class="inftable">
<tr><td>Pengarang</td><td>Chugong</td></tr>
<tr><td>Status</td><td>Ongoing</td></tr>
<tr><td>Judul Indonesia</td><td>Level Naik Sendirian</td></tr>
</table>
<ul class="genre">
  <li class="genre"><a><span>Action</span></a></li>
  <li class="genre"><a><span>Fantasy</span></a></li>
</ul>
<div class="ims"><img src="https://cdn.komiku.org/thumb.jpg?resize=1"></div>
<div id="Daftar_Chapter">
<table>
<tr><td class="judulseries"><a href="/manga/solo-leveling/chapter-1/">Chapter 1</a></td><td class="tanggalseries">2 jam lalu</td></tr>
<tr><td class="judulseries"><a href="/manga/solo-leveling/chapter-2/">Chapter 2</a></td><td class="tanggalseries">15/01/2024</td></tr>
</table>
</div>
</body></html>
''';

  const pagesHtml = '''
<html><body>
<div id="Baca_Komik">
<img src="https://cdn.komiku.org/pages/001.jpg">
<img src="https://cdn.komiku.org/pages/002.jpg">
</div>
</body></html>
''';

  setUp(() {
    mockClient = MockClient((request) async {
      final path = request.url.path;
      if (path == '/manga') return html(listHtml);
      if (path == '/manga/solo-leveling/') return html(detailHtml);
      if (path == '/manga/solo-leveling/chapter-1/') return html(pagesHtml);
      return http.Response('not found', 404);
    });
    source = KomikuSource(client: mockClient);
  });

  test('fetchPopular mengurai kartu manga & hasNextPage', () async {
    final result = await source.fetchPopular(1);
    expect(result.mangas, hasLength(2));
    expect(result.mangas.first.title, 'Solo Leveling');
    expect(result.mangas.first.url, 'https://komiku.org/manga/solo-leveling/');
    expect(result.mangas.first.thumbnailUrl, 'https://cdn.komiku.org/cover1.jpg');
    expect(result.hasNextPage, isTrue);
  });

  test('fetchMangaDetails mengurai sinopsis/author/genre/status/thumbnail',
      () async {
    final details =
        await source.fetchMangaDetails('https://komiku.org/manga/solo-leveling/');
    expect(details.description, contains('Cerita tentang pemburu terlemah.'));
    expect(details.description, contains('Judul Indonesia: Level Naik Sendirian'));
    expect(details.author, 'Chugong');
    expect(details.genres, ['Action', 'Fantasy']);
    expect(details.status, SourceMangaStatus.ongoing);
    expect(details.thumbnailUrl, 'https://cdn.komiku.org/thumb.jpg');
  });

  test('fetchChapterList mengurai judul chapter & tanggal relatif/absolut',
      () async {
    final chapters = await source
        .fetchChapterList('https://komiku.org/manga/solo-leveling/');
    expect(chapters, hasLength(2));
    expect(chapters[0].name, 'Chapter 1');
    expect(chapters[0].url,
        'https://komiku.org/manga/solo-leveling/chapter-1/');
    expect(chapters[0].dateUpload, isNotNull);
    expect(chapters[1].dateUpload, DateTime(2024, 1, 15));
  });

  test('fetchPageList mengambil semua gambar', () async {
    final pages = await source
        .fetchPageList('https://komiku.org/manga/solo-leveling/chapter-1/');
    expect(pages, hasLength(2));
    expect(pages[0].imageUrl, 'https://cdn.komiku.org/pages/001.jpg');
    expect(pages[1].imageUrl, 'https://cdn.komiku.org/pages/002.jpg');
  });
}
