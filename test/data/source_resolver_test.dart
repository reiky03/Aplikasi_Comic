import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aplikasi_komik/data/repository_state.dart';
import 'package:aplikasi_komik/data/source_resolver.dart';
import 'package:aplikasi_komik/data/sources_state.dart';
import 'package:aplikasi_komik/sources/adaptive_source.dart';
import 'package:aplikasi_komik/sources/extension_runtime_source.dart';
import 'package:aplikasi_komik/sources/source_catalog.dart';

void main() {
  test(
    'resolver mengembalikan extension runtime untuk komik dari repository',
    () {
      const repositories = [
        ComicRepository(
          id: 'repo',
          name: 'Repo Test',
          url: 'https://example.com/index.min.json',
          sources: [
            RepoSource(
              id: 'source',
              name: 'Source Repo',
              hue: 120,
              lang: 'EN',
              baseUrl: 'https://source.example',
              pkg: 'eu.kanade.tachiyomi.extension.en.test',
            ),
          ],
        ),
      ];

      final source = resolveMangaSource('Source Repo', const [], repositories);

      expect(source, isA<ExtensionRuntimeSource>());
      expect(
        (source! as ExtensionRuntimeSource).packageName,
        'eu.kanade.tachiyomi.extension.en.test',
      );
    },
  );

  test('resolver memakai base URL repo terbaru untuk sumber manual', () {
    const packageName = 'eu.kanade.tachiyomi.extension.en.test';
    const source = ComicSource(
      id: 'custom',
      name: 'Source Repo',
      url: 'domain-lama.example',
      lang: 'EN',
      hue: 120,
      parserKind: 'extension-runtime:$packageName',
      repoPackage: packageName,
      repoSourceId: 'source-id',
    );
    const repositories = [
      ComicRepository(
        id: 'repo',
        name: 'Repo Test',
        url: 'https://example.com/index.min.json',
        sources: [
          RepoSource(
            id: 'source-id',
            name: 'Source Repo',
            hue: 120,
            lang: 'EN',
            baseUrl: 'https://domain-baru.example',
            pkg: packageName,
          ),
        ],
      ),
    ];

    final resolved = resolveMangaSource('Source Repo', const [
      source,
    ], repositories);

    expect(resolved, isA<ExtensionRuntimeSource>());
    expect(resolved?.baseUrl, 'https://domain-baru.example');
  });

  test(
    'sumber manual mengalahkan domain built-in lama dan membawa alias nama',
    () {
      const source = ComicSource(
        id: 'ikiru-custom',
        name: 'Ikiru Baru',
        nameAliases: ['Ikiru'],
        url: 'domain-baru.ikiru.test',
        urlAliases: ['06.ikiru.wtf'],
        lang: 'ID',
        hue: 120,
        parserKind: 'natsuid',
      );

      final resolved = resolveMangaSource('Ikiru', const [source], const []);

      expect(resolved, isA<AdaptiveSource>());
      expect(resolved?.baseUrl, 'https://domain-baru.ikiru.test');
    },
  );

  test(
    'alias nama repository tetap membuka komik yang disimpan sebelum rename',
    () {
      const repositories = [
        ComicRepository(
          id: 'repo',
          name: 'Repo',
          url: 'https://repo.test/index.json',
          sources: [
            RepoSource(
              id: 'stable-id',
              name: 'Nama Baru',
              nameAliases: ['Nama Lama'],
              hue: 20,
              lang: 'ID',
              baseUrl: 'https://domain-baru.test',
              parserKind: 'universal-html',
            ),
          ],
        ),
      ];

      final resolved = resolveMangaSource('Nama Lama', const [], repositories);

      expect(resolved, isA<AdaptiveSource>());
      expect(resolved?.baseUrl, 'https://domain-baru.test');
    },
  );

  test('SourcesNotifier.syncWithRepositories menyelaraskan Sumber Saya dengan repo', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(sourcesProvider.notifier);

    // Initial seedSources memiliki AsuraToons (s1) dengan url 'asuratoons.example'
    const repos = [
      ComicRepository(
        id: 'r1',
        name: 'Repo Global',
        url: 'https://repo.example/index.json',
        sources: [
          RepoSource(
            id: 'asura-id',
            name: 'AsuraToons',
            hue: 265,
            lang: 'EN',
            baseUrl: 'https://asuracomics.gg',
            pkg: 'eu.kanade.tachiyomi.extension.en.asura',
          ),
        ],
      ),
    ];

    final synced = await notifier.syncWithRepositories(repos);
    expect(synced, greaterThan(0));

    final updatedSource = container
        .read(sourcesProvider)
        .firstWhere((s) => s.id == 's1');

    expect(updatedSource.url, 'https://asuracomics.gg');
    expect(updatedSource.repoPackage, 'eu.kanade.tachiyomi.extension.en.asura');
    expect(updatedSource.repoSourceId, 'asura-id');
    expect(updatedSource.parserKind, 'extension-runtime:eu.kanade.tachiyomi.extension.en.asura');
    expect(updatedSource.urlAliases, contains('asuratoons.example'));
  });

  test('resolver mencocokkan nama komik secara fuzzy dengan sameLibraryTitle', () {
    const repositories = [
      ComicRepository(
        id: 'repo',
        name: 'Repo',
        url: 'https://repo.test/index.json',
        sources: [
          RepoSource(
            id: 's1',
            name: 'Kiryuu ID',
            hue: 10,
            lang: 'ID',
            baseUrl: 'https://kiryuu.id',
            parserKind: 'mangathemesia',
          ),
        ],
      ),
    ];

    // Komik di library tersimpan dengan nama 'kiryuu-id' atau 'Kiryuu ID!!'
    final resolved = resolveMangaSource('Kiryuu ID!!', const [], repositories);
    expect(resolved, isNotNull);
    expect(resolved?.name, 'Kiryuu ID');
  });

  test('sumber built-in tetap mengutamakan parser native walau repositori memiliki package extension', () {
    const customSources = [
      ComicSource(
        id: 's_shinigami',
        name: 'Shinigami',
        url: 'https://shinigami.asia',
        lang: 'ID',
        hue: 0,
      ),
    ];
    const repositories = [
      ComicRepository(
        id: 'repo1',
        name: 'Repo Indo',
        url: 'https://repo.example/index.min.json',
        sources: [
          RepoSource(
            id: 'shinigami-repo',
            name: 'Shinigami',
            hue: 0,
            lang: 'ID',
            baseUrl: 'https://shinigami.asia',
            pkg: 'eu.kanade.tachiyomi.extension.id.shinigamito',
          ),
        ],
      ),
    ];

    final resolved = resolveMangaSource('Shinigami', customSources, repositories);
    expect(resolved, isNotNull);
    expect(resolved, isA<AdaptiveSource>());
  });

  test('sumber custom dengan parserKind web generik tidak tertimpa oleh extension package repo', () {
    const customSources = [
      ComicSource(
        id: 's_custom',
        name: 'WestManga',
        url: 'https://westmanga.info',
        lang: 'ID',
        hue: 30,
        parserKind: 'mangathemesia',
      ),
    ];
    const repositories = [
      ComicRepository(
        id: 'repo1',
        name: 'Repo Indo',
        url: 'https://repo.example/index.min.json',
        sources: [
          RepoSource(
            id: 'westmanga-repo',
            name: 'WestManga',
            hue: 30,
            lang: 'ID',
            baseUrl: 'https://westmanga.info',
            pkg: 'eu.kanade.tachiyomi.extension.id.westmanga',
          ),
        ],
      ),
    ];

    final resolved = resolveMangaSource('WestManga', customSources, repositories);
    expect(resolved, isNotNull);
    expect(resolved, isA<AdaptiveSource>());
  });

  test('updateSourceUrl menyimpan domain lama ke urlAliases secara rapi', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(sourcesProvider.notifier);
    const initialSource = ComicSource(
      id: 'ikiru-test',
      name: 'Ikiru',
      url: 'https://07.ikiru.wtf',
      lang: 'ID',
      hue: 120,
    );
    await notifier.add(initialSource);

    final changed = await notifier.updateSourceUrl(
      'ikiru-test',
      'https://09.ikiru.wtf',
    );
    expect(changed, isTrue);

    final updated = container.read(sourcesProvider).firstWhere((s) => s.id == 'ikiru-test');
    expect(updated.url, 'https://09.ikiru.wtf');
    expect(updated.urlAliases, contains('https://07.ikiru.wtf'));
  });

  test('SourceCatalog mengenali domain baru Ikiru 09.ikiru.wtf dan portal ikiru.id', () {
    final match09 = SourceCatalog.matchByUrl('https://09.ikiru.wtf/manga/test-title');
    expect(match09, isNotNull);
    expect(match09!.name, 'Ikiru');

    final matchPortal = SourceCatalog.matchByUrl('https://ikiru.id');
    expect(matchPortal, isNotNull);
    expect(matchPortal!.name, 'Ikiru');
  });

  test(
    'resolver mencocokkan custom source lewat comicId atau host sourceMangaUrl bila nama berbeda',
    () {
      const customSources = [
        ComicSource(
          id: 'src_custom_1',
          name: 'Kiryuu ID Revamp',
          url: 'https://v7.kiryuu.to',
          lang: 'ID',
          hue: 45,
          parserKind: 'mangathemesia',
        ),
      ];

      // Nama di komik hanya 'Kiryuu', tapi comicId membawa ID sumber
      final byId = resolveMangaSource(
        'Kiryuu',
        customSources,
        const [],
        comicId: 'src_src_custom_1_https%3A%2F%2Fv7.kiryuu.to%2Fmanga%2Ftest',
      );
      expect(byId, isNotNull);
      expect(byId?.baseUrl, 'https://v7.kiryuu.to');

      // Nama di komik berbeda tapi URL host cocok
      final byHost = resolveMangaSource(
        'Situs Lain',
        customSources,
        const [],
        sourceMangaUrl: 'https://v7.kiryuu.to/manga/solo-leveling',
      );
      expect(byHost, isNotNull);
      expect(byHost?.baseUrl, 'https://v7.kiryuu.to');
    },
  );

  test(
    'resolver menyelesaikan repo source dengan repo.url saat repoSource.baseUrl null',
    () {
      const repositories = [
        ComicRepository(
          id: 'repo_keiyoushi',
          name: 'Keiyoushi Extensions',
          url: 'https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json',
          sources: [
            RepoSource(
              id: 'repo_src_1',
              name: 'Komikcast Extension',
              hue: 200,
              lang: 'ID',
              baseUrl: null,
              pkg: 'eu.kanade.tachiyomi.extension.id.komikcast',
            ),
          ],
        ),
      ];

      final resolved = resolveMangaSource(
        'Komikcast Extension',
        const [],
        repositories,
      );
      expect(resolved, isNotNull);
      expect(resolved, isA<ExtensionRuntimeSource>());
    },
  );

  test(
    'resolver fallback otomatis ke origin sourceMangaUrl saat customSources & repositories kosong',
    () {
      // Skenario app baru dibuka di Library: snapshot Firestore belum selesai sync
      final resolved = resolveMangaSource(
        'Kiryuu',
        const [],
        const [],
        sourceMangaUrl: 'https://v7.kiryuu.to/manga/solo-leveling/',
      );

      expect(resolved, isNotNull);
      expect(resolved, isA<AdaptiveSource>());
      expect(resolved?.baseUrl, 'https://v7.kiryuu.to');
    },
  );
}
