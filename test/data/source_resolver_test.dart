import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aplikasi_komik/data/repository_state.dart';
import 'package:aplikasi_komik/data/source_resolver.dart';
import 'package:aplikasi_komik/data/sources_state.dart';
import 'package:aplikasi_komik/sources/adaptive_source.dart';
import 'package:aplikasi_komik/sources/extension_runtime_source.dart';

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
}
