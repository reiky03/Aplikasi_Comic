import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aplikasi_komik/sources/softkomik_source.dart';

void main() {
  const listHtml = '''
<!DOCTYPE html>
<html><body>
  <div class="content">
    <a href="/the-second-marriage-bahasa-indonesia">
      <img src="/_next/image?url=https%3A%2F%2Fcover.softdevices.my.id%2Fthe-second-marriage.jpg&w=384&q=75" alt="The Second Marriage">
      The Second Marriage
    </a>
    <a href="/downer-joushi-wa-sotonomi-shitai-bahasa-indonesia">
      <img src="https://cover.softdevices.my.id/downer.jpg" alt="Downer Joushi">
      Downer Joushi
    </a>
  </div>
</body></html>
''';

  const detailHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta property="og:description" content="Kisah pernikahan kedua Navier.">
  <meta property="og:image" content="https://cover.softdevices.my.id/the-second-marriage.jpg">
</head>
<body>
  <h1>The Second Marriage</h1>
  <a href="/the-second-marriage-bahasa-indonesia/chapter/246">Chapter 246</a>
  <a href="/the-second-marriage-bahasa-indonesia/chapter/245">Chapter 245</a>
</body>
</html>
''';

  const chapterHtml = '''
<!DOCTYPE html>
<html><body>
  <img src="https://psy1.komik.im/img-file/the-second-marriage/chapter-246/001.webp">
  <img src="https://psy1.komik.im/img-file/the-second-marriage/chapter-246/002.webp">
  <img src="/icon.jpg">
</body></html>
''';

  late SoftkomikSource source;

  setUp(() {
    source = SoftkomikSource(
      name: 'Softkomik',
      baseUrl: 'https://softkomik.app',
      client: MockClient((request) async {
        final path = request.url.path;
        if (path == '/komik/list' || path == '/') {
          return http.Response(listHtml, 200);
        }
        if (path == '/the-second-marriage-bahasa-indonesia') {
          return http.Response(detailHtml, 200);
        }
        if (path == '/the-second-marriage-bahasa-indonesia/chapter/246') {
          return http.Response(chapterHtml, 200);
        }
        return http.Response('not found', 404);
      }),
    );
  });

  test('Softkomik fetchPopular mengurai komik dan membersihkan URL cover', () async {
    final page = await source.fetchPopular(1);
    expect(page.mangas, hasLength(2));
    expect(page.mangas.first.title, 'The Second Marriage');
    expect(page.mangas.first.thumbnailUrl, 'https://cover.softdevices.my.id/the-second-marriage.jpg');
    expect(page.mangas.last.title, 'Downer Joushi');
    expect(page.mangas.last.thumbnailUrl, 'https://cover.softdevices.my.id/downer.jpg');
  });

  test('Softkomik fetchSearch mengirim parameter name dan mengurai komik', () async {
    final page = await source.fetchSearch('marriage', 1);
    expect(page.mangas, hasLength(2));
  });

  test('Softkomik fetchMangaDetails mengurai detail dan cover', () async {
    final detail = await source.fetchMangaDetails('/the-second-marriage-bahasa-indonesia');
    expect(detail.description, 'Kisah pernikahan kedua Navier.');
    expect(detail.thumbnailUrl, 'https://cover.softdevices.my.id/the-second-marriage.jpg');
  });

  test('Softkomik fetchChapterList mengurai daftar chapter', () async {
    final chapters = await source.fetchChapterList('/the-second-marriage-bahasa-indonesia');
    expect(chapters, hasLength(2));
    expect(chapters.first.name, 'Chapter 246');
    expect(chapters.first.url, 'https://softkomik.app/the-second-marriage-bahasa-indonesia/chapter/246');
  });

  test('Softkomik fetchPageList mengurai gambar pembaca dan mengabaikan ikon', () async {
    final pages = await source.fetchPageList('/the-second-marriage-bahasa-indonesia/chapter/246');
    expect(pages, hasLength(2));
    expect(pages.first.imageUrl, 'https://psy1.komik.im/img-file/the-second-marriage/chapter-246/001.webp');
    expect(pages.last.imageUrl, 'https://psy1.komik.im/img-file/the-second-marriage/chapter-246/002.webp');
  });
}
