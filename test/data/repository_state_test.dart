import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aplikasi_komik/data/repository_state.dart';

void main() {
  test('fetchRepositoryIndex mengurai index Tachiyomi-style', () async {
    const body = '''
[
  {
    "name": "Tachiyomi: Akuma",
    "pkg": "eu.kanade.tachiyomi.extension.all.akuma",
    "apk": "tachiyomi-all.akuma-v1.4.10.apk",
    "lang": "all",
    "version": "1.4.10",
    "code": 10,
    "sources": [
      {
        "name": "Akuma",
        "lang": "id",
        "id": "1707768678643970514",
        "baseUrl": "https://akuma.moe"
      }
    ]
  }
]
''';
    final result = await fetchRepositoryIndex(
      'https://repo.example/index.min.json',
      client: MockClient((_) async => http.Response(body, 200)),
    );

    expect(result.name, 'repo.example');
    expect(result.sources, hasLength(1));
    expect(result.sources.first.name, 'Akuma');
    expect(result.sources.first.lang, 'ID');
    expect(result.sources.first.baseUrl, 'https://akuma.moe');
    expect(result.sources.first.versionCode, 10);
    expect(result.sources.first.pkg, 'eu.kanade.tachiyomi.extension.all.akuma');
    expect(
      result.sources.first.parserKind,
      'extension-runtime:eu.kanade.tachiyomi.extension.all.akuma',
    );
  });

  test('repositoryApkUrl membentuk URL APK relatif dari index raw', () {
    expect(
      repositoryApkUrl(
        'https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json',
        'tachiyomi-id.komiku-v1.4.21.apk',
      ),
      'https://raw.githubusercontent.com/keiyoushi/extensions/repo/apk/tachiyomi-id.komiku-v1.4.21.apk',
    );
  });

  test('findRepoSourceForUrl mencocokkan domain sumber manual', () {
    const repo = ComicRepository(
      id: 'keiyoushi',
      name: 'Keiyoushi',
      url:
          'https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json',
      sources: [
        RepoSource(
          id: 'komiku',
          name: 'Komiku',
          hue: 200,
          lang: 'ID',
          baseUrl: 'https://komiku.org',
          pkg: 'eu.kanade.tachiyomi.extension.id.komiku',
          apk: 'tachiyomi-id.komiku-v1.4.21.apk',
        ),
      ],
    );

    final match = findRepoSourceForUrl('https://www.komiku.org/manga/foo', [
      repo,
    ]);

    expect(match?.repository.name, 'Keiyoushi');
    expect(match?.source.pkg, 'eu.kanade.tachiyomi.extension.id.komiku');
  });

  test('findRepoSource mengikuti identitas extension saat domain berubah', () {
    const repo = ComicRepository(
      id: 'repo',
      name: 'Repo',
      url: 'https://repo.example/index.min.json',
      sources: [
        RepoSource(
          id: 'source-stable-id',
          name: 'Source',
          hue: 10,
          lang: 'EN',
          baseUrl: 'https://domain-baru.example',
          pkg: 'eu.kanade.tachiyomi.extension.en.source',
        ),
      ],
    );

    final match = findRepoSource(
      repositories: const [repo],
      rawUrl: 'https://domain-lama.example',
      packageName: 'eu.kanade.tachiyomi.extension.en.source',
      sourceId: 'source-stable-id',
    );

    expect(match?.source.baseUrl, 'https://domain-baru.example');
  });

  test('repositoryUpdateAvailable membandingkan code dan versi', () {
    const byCode = RepoSource(
      id: 'source',
      name: 'Source',
      hue: 10,
      lang: 'EN',
      version: '1.4.20',
      versionCode: 20,
    );
    const byName = RepoSource(
      id: 'source',
      name: 'Source',
      hue: 10,
      lang: 'EN',
      version: '1.4.20',
    );

    expect(
      repositoryUpdateAvailable(source: byCode, installedVersionCode: 19),
      isTrue,
    );
    expect(
      repositoryUpdateAvailable(
        source: byName,
        installedVersionCode: 0,
        installedVersionName: '1.4.21',
      ),
      isFalse,
    );
  });
}
