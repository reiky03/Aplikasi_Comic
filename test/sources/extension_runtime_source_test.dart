import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aplikasi_komik/data/source_session_store.dart';
import 'package:aplikasi_komik/sources/alternative_source_methods.dart';
import 'package:aplikasi_komik/sources/extension_runtime_source.dart';
import 'package:aplikasi_komik/sources/manga_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('kizen/extension_runtime');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await SourceSessionStore.clearAll();
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

  test('request extension membawa cookie WebView sumber', () async {
    SharedPreferences.setMockInitialValues({
      'source_web_sessions_v1': jsonEncode({
        'reader.example': {
          'cookie': 'cf_clearance=token',
          'userAgent': 'WebView UA',
        },
      }),
    });
    await SourceSessionStore.initialize();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'fetchChapterListFromExtension');
          final arguments = Map<Object?, Object?>.from(call.arguments as Map);
          expect(arguments['sessionHeaders'], {
            'Cookie': 'cf_clearance=token',
            'User-Agent': 'WebView UA',
          });
          return [
            {'url': '/chapter-1', 'name': 'Chapter 1', 'dateUpload': 0},
          ];
        });

    final source = ExtensionRuntimeSource(
      name: 'Test',
      packageName: 'extension.test',
      baseUrl: 'https://reader.example',
      fallback: const _FallbackSource(),
    );

    final chapters = await source.fetchChapterList(
      'https://reader.example/manga/solo',
    );

    expect(chapters.single.name, 'Chapter 1');
  });

  test('semua parser gagal mengembalikan URL untuk WebView', () async {
    final source = ExtensionRuntimeSource(
      name: 'Test',
      packageName: 'extension.test',
      baseUrl: 'https://reader.example',
      fallback: const _EmptySource(),
      alternatives: AlternativeSourceMethods(
        name: 'Test',
        baseUrl: 'https://reader.example',
        strategies: const [_EmptySource()],
      ),
    );

    expect(
      () => source.fetchPageList('/chapter/1'),
      throwsA(
        isA<MangaSourceWebViewException>().having(
          (error) => error.url,
          'url',
          'https://reader.example/chapter/1',
        ),
      ),
    );
  });

  test('parser alternatif dipakai setelah fallback utama kosong', () async {
    final source = ExtensionRuntimeSource(
      name: 'Test',
      packageName: 'extension.test',
      baseUrl: 'https://reader.example',
      fallback: const _EmptySource(),
      alternatives: AlternativeSourceMethods(
        name: 'Test',
        baseUrl: 'https://reader.example',
        strategies: const [_AlternativeSource()],
      ),
    );

    final pages = await source.fetchPageList('/chapter/1');

    expect(pages.single.imageUrl, 'https://reader.example/images/1.jpg');
  });

  test(
    'latest memakai fallback lebih lengkap saat extension cuma mengirim 4',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'fetchLatestFromExtension');
            return {
              'source': {
                'packageName': 'extension.test',
                'sourceDir': '/extension.apk',
                'extensionClass': 'Test',
                'className': 'Test',
                'name': 'Test',
                'baseUrl': 'https://reader.example',
                'lang': 'id',
                'id': 1,
                'supportsLatest': true,
                'superclasses': <String>[],
              },
              'mangas': [
                for (var i = 0; i < 4; i++)
                  {
                    'url': '/manga/extension-$i',
                    'title': 'Extension $i',
                    'thumbnailUrl': null,
                    'headers': <String, String>{},
                  },
              ],
              'hasNextPage': false,
            };
          });
      final source = ExtensionRuntimeSource(
        name: 'Test',
        packageName: 'extension.test',
        baseUrl: 'https://reader.example',
        fallback: const _ExpandedLatestSource(),
        alternatives: AlternativeSourceMethods(
          name: 'Test',
          baseUrl: 'https://reader.example',
          strategies: const [_EmptySource()],
        ),
      );

      final page = await source.fetchLatest(1);

      expect(page.mangas, hasLength(5));
      expect(page.mangas.first.title, 'HTML 0');
    },
  );

  test(
    'latest Soulscans tetap mencoba katalog web walau extension mengirim banyak item',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'fetchLatestFromExtension');
            return {
              'source': <String, Object?>{},
              'mangas': [
                for (var i = 0; i < 20; i++)
                  {
                    'url': '/manga/stale-$i',
                    'title': 'Stale $i',
                    'thumbnailUrl': null,
                    'headers': <String, String>{},
                  },
              ],
              'hasNextPage': true,
            };
          });
      final source = ExtensionRuntimeSource(
        name: 'Soul Scans',
        packageName: 'extension.test',
        baseUrl: 'https://v1.soulscans.asia',
        fallback: const _FallbackSource(),
        alternatives: AlternativeSourceMethods(
          name: 'Soul Scans',
          baseUrl: 'https://v1.soulscans.asia',
          strategies: const [_EmptySource()],
        ),
      );

      final page = await source.fetchLatest(1);

      expect(page.mangas.single.title, 'Fallback Manga');
    },
  );
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

class _EmptySource extends _FallbackSource {
  const _EmptySource();

  @override
  Future<List<SourcePage>> fetchPageList(String chapterUrl) async => const [];

  @override
  Future<SourceMangaPage> fetchPopular(int page) async =>
      const SourceMangaPage(mangas: [], hasNextPage: false);
}

class _AlternativeSource extends _EmptySource {
  const _AlternativeSource();

  @override
  Future<List<SourcePage>> fetchPageList(String chapterUrl) async => const [
    SourcePage(index: 0, imageUrl: 'https://reader.example/images/1.jpg'),
  ];
}

class _ExpandedLatestSource extends _FallbackSource {
  const _ExpandedLatestSource();

  @override
  Future<SourceMangaPage> fetchLatest(int page) async => SourceMangaPage(
    mangas: [
      for (var i = 0; i < 5; i++)
        SourceManga(
          url: 'https://reader.example/manga/html-$i',
          title: 'HTML $i',
        ),
    ],
    hasNextPage: true,
  );
}
