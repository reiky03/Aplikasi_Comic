import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aplikasi_komik/sources/doujindesu_source.dart';
import 'package:aplikasi_komik/sources/manga_source.dart';
import 'package:aplikasi_komik/sources/source_catalog.dart';

int _toSigned32(int x) {
  var y = x & 0xFFFFFFFF;
  if (y >= 0x80000000) y -= 0x100000000;
  return y;
}

String _wH(int e) {
  const salt = 'doujindesu-scrapers-cannot-read-this-super-secret-salt-2026-v2';
  final t = '${salt}_$e';
  var a = 0;
  for (var i = 0; i < t.length; i++) {
    a = (a << 5) - a + t.codeUnitAt(i);
    a = _toSigned32(a);
  }
  var l = a != 0 ? a.abs() : 123456789;
  final buffer = StringBuffer();
  for (var i = 0; i < 32; i++) {
    l = (l * 1664525 + 1013904223) % 4294967296;
    buffer.writeCharCode(33 + (l % 93));
  }
  return buffer.toString();
}

String _encrypt(String raw) {
  final quoted = Uri.encodeComponent(raw);
  final now = DateTime.now().millisecondsSinceEpoch;
  final t = (now / 3600000).floor();
  final key = _wH(t);
  final keyLen = key.length;
  var d = 42;
  final hex = StringBuffer();
  final bytes = utf8.encode(quoted);
  for (var idx = 0; idx < bytes.length; idx++) {
    final keyChar = key.codeUnitAt(idx % keyLen);
    // bytes[idx] = byteVal ^ keyChar ^ (idx * 13) ^ d
    // => byteVal = bytes[idx] ^ keyChar ^ (idx * 13) ^ d
    final byteVal = (bytes[idx] ^ keyChar ^ (idx * 13) ^ d) & 0xFF;
    hex.write(byteVal.toRadixString(16).padLeft(2, '0'));
    d = (d + byteVal) % 256;
  }
  return '{"_enc_resp_":"$hex"}';
}

void main() {
  group('DoujindesuSource Tests', () {
    late DoujindesuSource source;
    late List<Uri> requests;

    setUp(() {
      requests = [];
      source = DoujindesuSource(
        client: MockClient((request) async {
          requests.add(request.url);
          final path = request.url.path;

          if (path == '/api/manga') {
            final query = request.url.queryParameters['search'];
            if (query != null && query.isNotEmpty) {
              return http.Response(
                _encrypt('''[{"id":"s1","slug":"search-comic","title":"Hasil Pencarian","cover_url":"https://cdn.example/s1.webp"}]'''),
                200,
              );
            }
            return http.Response(
              _encrypt('''[
                {"id":"1","slug":"manga-satu","title":"Komik Pertama","cover_url":"https://cdn.example/1.webp","author":"Author 1"},
                {"id":"2","slug":"manga-dua","title":"Komik Kedua","cover_url":"https://cdn.example/2.webp","author":"Author 2"}
              ]'''),
              200,
            );
          }

          if (path == '/api/manga/manga-satu') {
            return http.Response(
              _encrypt('''{
                "id":"1",
                "slug":"manga-satu",
                "title":"Komik Pertama",
                "description":"Sinopsis komik pertama",
                "cover_url":"https://cdn.example/1.webp",
                "author":"Author 1",
                "artist":"Artist 1",
                "status":"ongoing",
                "manga_genres":[{"genre":{"name":"Action"}},{"genre":{"name":"Romance"}}],
                "chapters":[
                  {"id":"ch-101","chapter_number":1,"title":"Chapter 1","created_at":"2026-11-04T12:00:00Z"},
                  {"id":"ch-102","chapter_number":2,"title":"Chapter 2","created_at":"2026-11-04T14:00:00Z"}
                ]
              }'''),
              200,
            );
          }

          if (path == '/api/chapters/ch-101') {
            return http.Response(
              _encrypt('''{
                "id":"ch-101",
                "content_urls":[
                  "https://cdn.example/pages/1.webp",
                  "https://cdn.example/pages/2.webp",
                  "https://cdn.example/pages/3.webp"
                ]
              }'''),
              200,
            );
          }

          return http.Response('not found', 404);
        }),
      );
    });

    test('fetchPopular mengembalikan daftar manga dan mendeteksi hasNextPage', () async {
      final page = await source.fetchPopular(1);
      expect(page.mangas.length, 2);
      expect(page.mangas.first.title, 'Komik Pertama');
      expect(page.mangas.first.url, '/manga/manga-satu/');
      expect(page.mangas.first.thumbnailUrl, 'https://cdn.example/1.webp');
      expect(requests.first.path, '/api/manga');
    });

    test('fetchSearch mengembalikan hasil pencarian', () async {
      final page = await source.fetchSearch('test', 1);
      expect(page.mangas.length, 1);
      expect(page.mangas.first.title, 'Hasil Pencarian');
      expect(page.mangas.first.url, '/manga/search-comic/');
      expect(requests.first.queryParameters['search'], 'test');
    });

    test('fetchMangaDetails mengembalikan metadata komik lengkap', () async {
      final details = await source.fetchMangaDetails('/manga/manga-satu/');
      expect(details.description, 'Sinopsis komik pertama');
      expect(details.author, 'Author 1');
      expect(details.artist, 'Artist 1');
      expect(details.status, SourceMangaStatus.ongoing);
      expect(details.genres, ['Action', 'Romance']);
      expect(details.thumbnailUrl, 'https://cdn.example/1.webp');
    });

    test('fetchChapterList mengembalikan daftar chapter', () async {
      final chapters = await source.fetchChapterList('/manga/manga-satu/');
      expect(chapters.length, 2);
      expect(chapters.first.url, '/chapter/ch-101');
      expect(chapters.first.name, 'Chapter 1');
      expect(chapters.last.url, '/chapter/ch-102');
      expect(chapters.last.name, 'Chapter 2');
    });

    test('fetchPageList mengembalikan semua url gambar langsung', () async {
      final pages = await source.fetchPageList('/chapter/ch-101');
      expect(pages.length, 3);
      expect(pages[0].index, 0);
      expect(pages[0].imageUrl, 'https://cdn.example/pages/1.webp');
      expect(pages[1].imageUrl, 'https://cdn.example/pages/2.webp');
      expect(pages[2].imageUrl, 'https://cdn.example/pages/3.webp');
      expect(pages[0].headers['Referer'], contains('doujin.desu.xxx'));
    });

    test('SourceCatalog.buildAutomatic mengenali domain Doujindesu dan mengembalikan DoujindesuSource', () {
      final s = SourceCatalog.buildAutomatic('Doujindesu', 'https://doujin.desu.xxx');
      expect(s, isA<DoujindesuSource>());
    });
  });
}
