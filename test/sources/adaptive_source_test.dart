import 'package:flutter_test/flutter_test.dart';

import 'package:aplikasi_komik/sources/adaptive_source.dart';
import 'package:aplikasi_komik/sources/manga_source.dart';

void main() {
  test(
    'parser adaptif lanjut ke strategi berikutnya saat yang utama gagal',
    () async {
      final gagal = _FakeSource(failPopular: true);
      final berhasil = _FakeSource(
        popular: const SourceMangaPage(
          mangas: [SourceManga(url: '/manga/ok', title: 'Berhasil')],
          hasNextPage: false,
        ),
      );
      final source = AdaptiveSource(
        name: 'Dinamis',
        baseUrl: 'https://baru.test',
        strategies: [gagal, berhasil],
      );

      final result = await source.fetchPopular(1);

      expect(result.mangas.single.title, 'Berhasil');
      expect(gagal.popularCalls, 1);
      expect(berhasil.popularCalls, 1);
    },
  );

  test(
    'parser adaptif mengirim URL Library lama memakai domain aktif',
    () async {
      final recorder = _FakeSource(baseUrl: 'https://domain-baru.test');
      final source = AdaptiveSource(
        name: 'Dinamis',
        baseUrl: 'https://domain-baru.test',
        strategies: [recorder],
      );

      await source.fetchChapterList('https://domain-lama.test/manga/seri-a');

      expect(recorder.lastMangaUrl, 'https://domain-baru.test/manga/seri-a');
    },
  );

  test('setiap strategi domain menerima URL yang sudah di-rebase', () async {
    final primary = _FakeSource(
      baseUrl: 'https://utama.test',
      failChapters: true,
    );
    final mirror = _FakeSource(baseUrl: 'https://mirror.test');
    final source = AdaptiveSource(
      name: 'Dinamis',
      baseUrl: 'https://utama.test',
      strategies: [primary, mirror],
    );

    await source.fetchChapterList('https://domain-lama.test/manga/seri-a');

    expect(primary.lastMangaUrl, 'https://utama.test/manga/seri-a');
    expect(mirror.lastMangaUrl, 'https://mirror.test/manga/seri-a');
  });

  test(
    'latest yang identik dengan populer meneruskan strategi sampai berbeda',
    () async {
      const same = SourceMangaPage(
        mangas: [SourceManga(url: '/manga/sama', title: 'Daftar Sama')],
        hasNextPage: false,
      );
      const distinct = SourceMangaPage(
        mangas: [SourceManga(url: '/manga/baru', title: 'Benar Terbaru')],
        hasNextPage: false,
      );
      final stale = _FakeSource(popular: same, latest: same);
      final fresh = _FakeSource(latest: distinct);
      final source = AdaptiveSource(
        name: 'Dinamis',
        baseUrl: 'https://baru.test',
        strategies: [stale, fresh],
      );

      await source.fetchPopular(1);
      final latest = await source.fetchLatest(1);

      expect(latest.mangas.single.title, 'Benar Terbaru');
      expect(stale.latestCalls, 1);
      expect(fresh.latestCalls, 1);
    },
  );
}

class _FakeSource implements MangaSource {
  _FakeSource({
    this.baseUrl = 'https://fake.test',
    this.failPopular = false,
    this.failChapters = false,
    this.popular = const SourceMangaPage(mangas: [], hasNextPage: false),
    this.latest,
  });

  @override
  final String baseUrl;
  final bool failPopular;
  final bool failChapters;
  final SourceMangaPage popular;
  final SourceMangaPage? latest;
  int popularCalls = 0;
  int latestCalls = 0;
  String? lastMangaUrl;

  @override
  String get name => 'Fake';

  @override
  Future<SourceMangaPage> fetchPopular(int page) async {
    popularCalls++;
    if (failPopular) throw const MangaSourceException('gagal');
    return popular;
  }

  @override
  Future<SourceMangaPage> fetchLatest(int page) async {
    latestCalls++;
    return latest ?? popular;
  }

  @override
  Future<SourceMangaPage> fetchSearch(String query, int page) =>
      fetchPopular(page);

  @override
  Future<SourceMangaDetails> fetchMangaDetails(String mangaUrl) async {
    lastMangaUrl = mangaUrl;
    return const SourceMangaDetails(description: 'Ada');
  }

  @override
  Future<List<SourceChapter>> fetchChapterList(String mangaUrl) async {
    lastMangaUrl = mangaUrl;
    if (failChapters) throw const MangaSourceException('gagal');
    return const [SourceChapter(url: '/chapter/1', name: 'Chapter 1')];
  }

  @override
  Future<List<SourcePage>> fetchPageList(String chapterUrl) async => const [
    SourcePage(index: 0, imageUrl: 'https://cdn.test/1.jpg'),
  ];
}
