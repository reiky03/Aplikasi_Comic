import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aplikasi_komik/sources/mangafire_source.dart';
import 'package:aplikasi_komik/sources/source_catalog.dart';

void main() {
  late MangaFireSource source;
  late List<Uri> requests;

  setUp(() {
    requests = [];
    source = MangaFireSource(
      client: MockClient((request) async {
        requests.add(request.url);
        final path = request.url.path;
        if (path == '/api/titles' &&
            request.url.queryParameters['keyword'] != null) {
          return http.Response(_titlesJson('Search Result'), 200);
        }
        if (path == '/api/titles') {
          return http.Response(_titlesJson('Popular Fire'), 200);
        }
        if (path == '/api/titles/abc123') {
          return http.Response('''
{"data":{"hid":"abc123","slug":"fire-knight","title":"Fire Knight",
"type":"manga","status":"releasing",
"synopsisHtml":"<p>A knight of flame.</p>",
"authors":[{"title":"Author A"}],"artists":[{"title":"Artist B"}],
"genres":[{"title":"Action"}],"themes":[{"title":"Magic"}],
"poster":{"large":"https://cdn.example/fire-large.webp"}}}
''', 200);
        }
        if (path == '/api/titles/abc123/chapters') {
          final page = request.url.queryParameters['page'];
          return http.Response(
            page == '1'
                ? '''{"items":[{"id":91,"number":12,"name":"Awakening","createdAt":1721433600}],"meta":{"lastPage":2}}'''
                : '''{"items":[{"id":90,"number":11.5,"createdAt":1721347200}],"meta":{"lastPage":2}}''',
            200,
          );
        }
        if (path == '/api/chapters/91') {
          return http.Response('''
{"data":{"pages":[{"url":"https://img.example/001.webp"},{"url":"/images/002.webp"}]}}
''', 200);
        }
        return http.Response('not found', 404);
      }),
    );
  });

  test('popular, latest, dan search memakai endpoint API titles', () async {
    final popular = await source.fetchPopular(1);
    final latest = await source.fetchLatest(2);
    final search = await source.fetchSearch('fire', 1);

    expect(popular.mangas.single.title, 'Popular Fire');
    expect(popular.mangas.single.url, '/title/abc123-fire-knight');
    expect(popular.hasNextPage, isTrue);
    expect(requests[0].queryParameters['order[views_30d]'], 'desc');
    expect(requests[1].queryParameters['order[chapter_updated_at]'], 'desc');
    expect(requests[2].queryParameters['keyword'], 'fire');
    expect(latest.mangas, isNotEmpty);
    expect(search.mangas.single.title, 'Search Result');
  });

  test('detail mengurai metadata dan sinopsis HTML', () async {
    final details = await source.fetchMangaDetails(
      'https://mangafire.to/title/abc123-fire-knight',
    );

    expect(details.description, 'A knight of flame.');
    expect(details.author, 'Author A');
    expect(details.artist, 'Artist B');
    expect(details.genres, ['Manga', 'Action', 'Magic']);
    expect(details.status.name, 'ongoing');
  });

  test('chapter mengambil semua halaman API dan tanggal epoch', () async {
    final chapters = await source.fetchChapterList(
      'https://mangafire.to/title/abc123-fire-knight',
    );

    expect(chapters, hasLength(2));
    expect(chapters.first.name, 'Ch. 12 - Awakening');
    expect(chapters.first.url, '/title/abc123-fire-knight/91-chapter-12-en');
    expect(
      chapters.first.dateUpload,
      DateTime.fromMillisecondsSinceEpoch(1721433600000),
    );
    expect(chapters.last.name, 'Ch. 11.5');
  });

  test('reader mengambil URL gambar dari API chapter', () async {
    final pages = await source.fetchPageList(
      '/title/abc123-fire-knight/91-chapter-12-en',
    );

    expect(pages, hasLength(2));
    expect(pages.first.imageUrl, 'https://img.example/001.webp');
    expect(pages.last.imageUrl, 'https://mangafire.to/images/002.webp');
  });

  test('source lama otomatis diarahkan ke parser MangaFire', () {
    final resolved = SourceCatalog.buildGeneric(
      'universal-html',
      'MangaFire Lama',
      'https://mangafire.to/',
    );

    expect(resolved, isA<MangaFireSource>());
  });
}

String _titlesJson(String title) =>
    '''
{"items":[{"hid":"abc123","slug":"fire-knight","title":"$title",
"poster":{"small":"https://cdn.example/fire.webp"}}],
"meta":{"hasNext":true,"lastPage":3}}
''';
