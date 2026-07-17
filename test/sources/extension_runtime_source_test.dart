import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aplikasi_komik/sources/extension_runtime_source.dart';
import 'package:aplikasi_komik/sources/manga_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('kizen/extension_runtime');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('hasil extension kosong otomatis memakai parser fallback', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'fetchPopularFromExtension');
          return {
            'source': {
              'packageName': 'extension.test',
              'sourceDir': '/extension.apk',
              'extensionClass': 'Test',
              'className': 'Test',
              'name': 'Test',
              'baseUrl': 'https://reader.example',
              'lang': 'en',
              'id': 1,
              'supportsLatest': true,
              'superclasses': <String>[],
            },
            'mangas': <Object?>[],
            'hasNextPage': false,
          };
        });
    final source = ExtensionRuntimeSource(
      name: 'Test',
      packageName: 'extension.test',
      baseUrl: 'https://reader.example',
      fallback: const _FallbackSource(),
    );

    final page = await source.fetchPopular(1);

    expect(page.mangas.single.title, 'Fallback Manga');
  });
}

class _FallbackSource implements MangaSource {
  const _FallbackSource();

  @override
  String get name => 'Fallback';

  @override
  String get baseUrl => 'https://reader.example';

  @override
  Future<SourceMangaPage> fetchPopular(int page) async => const SourceMangaPage(
    mangas: [
      SourceManga(
        url: 'https://reader.example/manga/fallback',
        title: 'Fallback Manga',
      ),
    ],
    hasNextPage: false,
  );

  @override
  Future<SourceMangaPage> fetchLatest(int page) => fetchPopular(page);

  @override
  Future<SourceMangaPage> fetchSearch(String query, int page) =>
      fetchPopular(page);

  @override
  Future<SourceMangaDetails> fetchMangaDetails(String mangaUrl) async =>
      const SourceMangaDetails();

  @override
  Future<List<SourceChapter>> fetchChapterList(String mangaUrl) async =>
      const [];

  @override
  Future<List<SourcePage>> fetchPageList(String chapterUrl) async => const [];
}
