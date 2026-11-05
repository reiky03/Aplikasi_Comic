import 'package:flutter_test/flutter_test.dart';

import 'package:aplikasi_komik/sources/manga_source.dart';
import 'package:aplikasi_komik/sources/source_catalog.dart';

void main() {
  test('URL Shinigami tetap dikenali sebagai parser native', () {
    final source = SourceCatalog.matchByUrl('https://g.shinigami.asia');

    expect(source, isNotNull);
    expect(source!.name, 'Shinigami');
  });

  test(
    'mirror bernomor dan nama Shinigami memakai parser native yang sama',
    () {
      final byMirror = SourceCatalog.matchByUrl('https://11.shinigami.asia');
      final byName = SourceCatalog.matchByName(
        'Shinigami',
        'https://domain-mirror-baru.example',
      );

      expect(byMirror?.name, 'Shinigami');
      expect(byName?.name, 'Shinigami');
    },
  );

  test('Ikiru mengenali domain bernomor dan kanonis terbaru 09', () {
    final mirror = SourceCatalog.matchByUrl('https://06.ikiru.wtf');
    final builtIn = SourceCatalog.sources.firstWhere(
      (source) => source.name == 'Ikiru',
    );

    expect(mirror?.name, 'Ikiru');
    expect(builtIn.baseUrl, 'https://09.ikiru.wtf');
    expect(
      SourceCatalog.buildGeneric('madara', 'Madara', 'https://madara.example'),
      isNotNull,
    );
    expect(
      SourceCatalog.buildGeneric('softkomik', 'Softkomik', 'https://softkomik.app'),
      isNotNull,
    );
  });

  test('probe source hanya hijau kalau katalog benar-benar berisi', () async {
    expect(
      await SourceCatalog.probeSource(const _ProbeSource(hasCatalog: true)),
      isTrue,
    );
    expect(
      await SourceCatalog.probeSource(const _ProbeSource(hasCatalog: false)),
      isFalse,
    );
    expect(
      await SourceCatalog.probeSource(const _ProbeSource(throws: true)),
      isFalse,
    );
  });
}

class _ProbeSource implements MangaSource {
  const _ProbeSource({this.hasCatalog = false, this.throws = false});

  final bool hasCatalog;
  final bool throws;

  @override
  String get name => 'Probe';

  @override
  String get baseUrl => 'https://probe.example';

  @override
  Future<SourceMangaPage> fetchPopular(int page) async {
    if (throws) throw const MangaSourceException('gagal');
    return SourceMangaPage(
      mangas: hasCatalog
          ? const [SourceManga(url: '/manga/1', title: 'Berhasil')]
          : const [],
      hasNextPage: false,
    );
  }

  @override
  Future<List<SourceChapter>> fetchChapterList(String mangaUrl) =>
      throw UnimplementedError();

  @override
  Future<SourceMangaDetails> fetchMangaDetails(String mangaUrl) =>
      throw UnimplementedError();

  @override
  Future<SourceMangaPage> fetchLatest(int page) => throw UnimplementedError();

  @override
  Future<List<SourcePage>> fetchPageList(String chapterUrl) =>
      throw UnimplementedError();

  @override
  Future<SourceMangaPage> fetchSearch(String query, int page) =>
      throw UnimplementedError();
}
