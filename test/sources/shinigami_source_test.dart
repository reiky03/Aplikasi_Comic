import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aplikasi_komik/sources/manga_source.dart';
import 'package:aplikasi_komik/sources/shinigami_source.dart';

/// Fixture JSON persis bentuk respons api.shngm.io (lihat ShinigamiDto.kt
/// di keiyoushi/extensions-source) — dipakai supaya parsing tervalidasi
/// tanpa perlu akses internet asli.
void main() {
  late http.Client mockClient;
  late ShinigamiSource source;

  http.Response jsonResponse(Map<String, dynamic> body) =>
      http.Response(jsonEncode(body), 200);

  setUp(() {
    mockClient = MockClient((request) async {
      final path = request.url.path;

      if (path == '/v1/manga/list') {
        return jsonResponse({
          'data': [
            {
              'cover_image_url': 'https://cdn.example/cover1.jpg',
              'manga_id': 'abc123',
              'title': 'Solo Leveling',
            },
            {
              'cover_image_url': 'https://cdn.example/cover2.jpg',
              'manga_id': 'def456',
              'title': 'Tower of God',
            },
          ],
          'meta': {'page': 1, 'total_page': 5},
        });
      }
      if (path == '/v1/manga/detail/abc123') {
        return jsonResponse({
          'data': {
            'description': 'Cerita tentang pemburu terlemah.',
            'status': 1,
            'taxonomy': {
              'Author': [
                {'name': 'Chugong'}
              ],
              'Artist': [
                {'name': 'Jang Sung-rak'}
              ],
              'Genre': [
                {'name': 'Action'},
                {'name': 'Fantasy'},
              ],
              'Format': [
                {'name': 'Manhwa'}
              ],
            },
          },
        });
      }
      if (path == '/v1/chapter/abc123/list') {
        return jsonResponse({
          'data': [
            {
              'release_date': '2024-01-15T10:30:00Z',
              'chapter_title': 'Awakening',
              'chapter_number': 1.0,
              'chapter_id': 'ch1',
            },
            {
              'release_date': '2024-01-20T10:30:00Z',
              'chapter_title': '',
              'chapter_number': 1.5,
              'chapter_id': 'ch1-5',
            },
          ],
        });
      }
      if (path == '/v1/chapter/detail/ch1') {
        return jsonResponse({
          'data': {
            'base_url': 'https://cdn.shngm.io',
            'chapter': {
              'path': '/manga/abc123/ch1/',
              'data': ['001.jpg', '002.jpg', '003.jpg'],
            },
          },
        });
      }
      return http.Response('not found', 404);
    });
    source = ShinigamiSource(client: mockClient);
  });

  test('fetchPopular mengurai daftar manga & hasNextPage', () async {
    final result = await source.fetchPopular(1);
    expect(result.mangas, hasLength(2));
    expect(result.mangas.first.title, 'Solo Leveling');
    expect(result.mangas.first.url, 'abc123');
    expect(result.mangas.first.thumbnailUrl, 'https://cdn.example/cover1.jpg');
    expect(result.hasNextPage, isTrue);
  });

  test('fetchMangaDetails mengurai deskripsi/author/genre/status', () async {
    final details = await source.fetchMangaDetails('abc123');
    expect(details.description, 'Cerita tentang pemburu terlemah.');
    expect(details.author, 'Chugong');
    expect(details.artist, 'Jang Sung-rak');
    expect(details.genres, ['Action', 'Fantasy', 'Manhwa']);
    expect(details.status, SourceMangaStatus.ongoing);
  });

  test('fetchChapterList mengurai nomor/judul chapter & tanggal', () async {
    final chapters = await source.fetchChapterList('abc123');
    expect(chapters, hasLength(2));
    expect(chapters[0].name, 'Chapter 1 Awakening');
    expect(chapters[0].url, 'ch1');
    expect(chapters[0].dateUpload, DateTime.utc(2024, 1, 15, 10, 30));
    // Nomor desimal (1.5) tidak boleh kehilangan ".5"-nya.
    expect(chapters[1].name, 'Chapter 1.5');
  });

  test('fetchPageList menggabungkan base_url + path + nama file', () async {
    final pages = await source.fetchPageList('ch1');
    expect(pages, hasLength(3));
    expect(pages[0].imageUrl, 'https://cdn.shngm.io/manga/abc123/ch1/001.jpg');
    expect(pages[2].imageUrl, 'https://cdn.shngm.io/manga/abc123/ch1/003.jpg');
  });
}
