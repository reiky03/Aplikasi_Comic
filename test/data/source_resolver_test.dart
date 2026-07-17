import 'package:flutter_test/flutter_test.dart';

import 'package:aplikasi_komik/data/repository_state.dart';
import 'package:aplikasi_komik/data/source_resolver.dart';
import 'package:aplikasi_komik/data/sources_state.dart';
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
}
