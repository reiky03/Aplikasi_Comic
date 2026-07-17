import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aplikasi_komik/sources/asura_source.dart';
import 'package:aplikasi_komik/sources/manga_source.dart';

void main() {
  late AsuraSource source;

  http.Response html(String body) => http.Response(body, 200);
  http.Response json(String body) =>
      http.Response(body, 200, headers: {'content-type': 'application/json'});

  const searchJson = '''
{
  "data": [
    {
      "id": 2056,
      "slug": "murim-login",
      "title": "Murim Login",
      "cover": "https://cdn.asura/covers/murim.webp",
      "public_url": "/comics/murim-login-1d35e5bd"
    }
  ]
}
''';

  const detailHtml = '''
<html><body>
<astro-island props='{"title":[0,"Murim Login"],"description":[0,"<p>Hunter masuk dunia murim.</p>"],"coverUrl":[0,"https://cdn.asura/covers/murim.webp"],"status":[0,"hiatus"],"author":[0,"Zerobic"],"artist":[0,"Kenaz"],"genres":[1,[[0,{"name":[0,"Action"]}],[0,{"name":[0,"Murim"]}]]]}'>
</astro-island>
</body></html>
''';

  const chaptersJson = '''
{
  "data": [
    {
      "id": 170828,
      "number": 250,
      "title": "S3 END",
      "slug": "uuid",
      "published_at": "2026-02-10T02:47:15Z"
    },
    {
      "id": 169419,
      "number": 249,
      "slug": "uuid-2",
      "published_at": "2026-02-04T03:45:10Z"
    }
  ]
}
''';

  const pagesHtml = '''
<html><body>
<astro-island props='{"pages":[1,[[0,{"url":[0,"https://cdn.asura/pages/001.webp"],"width":[0,800],"height":[0,12000]}],[0,{"url":[0,"https://cdn.asura/pages/002.webp"],"width":[0,800],"height":[0,11800]}]]]}'>
</astro-island>
</body></html>
''';

  setUp(() {
    source = AsuraSource(
      client: MockClient((request) async {
        final url = request.url.toString();
        if (url.startsWith('https://api.asurascans.com/api/search')) {
          return json(searchJson);
        }
        if (url ==
            'https://api.asurascans.com/api/series/murim-login-1d35e5bd/chapters') {
          return json(chaptersJson);
        }
        if (url == 'https://asurascans.com/comics/murim-login-1d35e5bd') {
          return html(detailHtml);
        }
        if (url ==
            'https://asurascans.com/comics/murim-login-1d35e5bd/chapter/uuid') {
          return html(pagesHtml);
        }
        return http.Response('not found', 404);
      }),
    );
  });

  test('fetchSearch mengurai hasil API Asura', () async {
    final result = await source.fetchSearch('murim', 1);
    expect(result.mangas, hasLength(1));
    expect(result.mangas.first.title, 'Murim Login');
    expect(
      result.mangas.first.url,
      'https://asurascans.com/comics/murim-login-1d35e5bd',
    );
    expect(
      result.mangas.first.thumbnailUrl,
      'https://cdn.asura/covers/murim.webp',
    );
  });

  test('fetchMangaDetails mengurai props Astro', () async {
    final details = await source.fetchMangaDetails(
      'https://asurascans.com/comics/murim-login-1d35e5bd',
    );
    expect(details.description, 'Hunter masuk dunia murim.');
    expect(details.author, 'Zerobic');
    expect(details.artist, 'Kenaz');
    expect(details.genres, ['Action', 'Murim']);
    expect(details.status, SourceMangaStatus.hiatus);
  });

  test('fetchChapterList memakai endpoint API series slug', () async {
    final chapters = await source.fetchChapterList(
      'https://asurascans.com/comics/murim-login-1d35e5bd',
    );
    expect(chapters, hasLength(2));
    expect(chapters.first.name, 'Chapter 250 · S3 END');
    expect(
      chapters.first.url,
      'https://asurascans.com/comics/murim-login-1d35e5bd/chapter/uuid',
    );
    expect(chapters.first.dateUpload, DateTime.utc(2026, 2, 10, 2, 47, 15));
  });

  test('fetchPageList mengurai daftar image props Astro', () async {
    final pages = await source.fetchPageList(
      'https://asurascans.com/comics/murim-login-1d35e5bd/chapter/uuid',
    );
    expect(pages, hasLength(2));
    expect(pages.first.imageUrl, 'https://cdn.asura/pages/001.webp');
    expect(pages.first.width, 800);
    expect(pages.first.height, 12000);
    expect(pages.first.headers['Referer'], 'https://asurascans.com/');
  });
}
