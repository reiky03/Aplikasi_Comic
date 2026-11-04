import 'package:archive/archive.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aplikasi_komik/data/generated/repository_index.pb.dart'
    as repo_pb;
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

  test('fetchRepositoryIndex mengurai index.pb gzip resmi', () async {
    final index = repo_pb.Index(
      name: 'Keiyoushi',
      extensionList: repo_pb.ExtensionList(extensions: [_protoExtension()]),
    );
    final body = GZipEncoder().encode(index.writeToBuffer());

    final result = await fetchRepositoryIndex(
      'https://repo.example/index.pb',
      client: MockClient((request) async {
        expect(request.headers['accept'], contains('application/protobuf'));
        return http.Response.bytes(body, 200);
      }),
    );

    expect(result.name, 'Keiyoushi');
    expect(result.sources, hasLength(1));
    expect(result.sources.single.id, '1707768678643970514');
    expect(result.sources.single.name, 'Ikiru');
    expect(result.sources.single.lang, 'ID');
    expect(result.sources.single.baseUrl, 'https://ikiru.example');
    expect(result.sources.single.baseUrlAliases, [
      'https://mirror.ikiru.example',
    ]);
    expect(
      result.sources.single.apk,
      'https://cdn.example/tachiyomi-id.ikiru-v1.4.30.apk',
    );
    expect(result.sources.single.versionCode, 30);
  });

  test(
    'URL index JSON lama otomatis mengikuti repo.json dan index_v2',
    () async {
      final requested = <String>[];
      final index = repo_pb.Index(
        name: 'Repo Baru',
        extensionList: repo_pb.ExtensionList(extensions: [_protoExtension()]),
      );
      final protobufBody = GZipEncoder().encode(index.writeToBuffer());
      final client = MockClient((request) async {
        requested.add(request.url.path);
        return switch (request.url.path) {
          '/index.min.json' => http.Response('hilang', 404),
          '/repo.json' => http.Response(
            '{"index_v2":"https://repo.example/index.pb",'
            '"meta":{"name":"Repo Baru"}}',
            200,
          ),
          '/index.pb' => http.Response.bytes(protobufBody, 200),
          _ => http.Response('tidak ditemukan', 404),
        };
      });

      final result = await fetchRepositoryIndex(
        'https://repo.example/index.min.json',
        client: client,
      );

      expect(requested, ['/index.min.json', '/repo.json', '/index.pb']);
      expect(result.name, 'Repo Baru');
      expect(result.sources.single.name, 'Ikiru');
    },
  );

  test('index.pb dapat mengambil ExtensionList dari URL terpisah', () async {
    final index = repo_pb.Index(
      name: 'Repo Terpisah',
      extensionListUrl: 'extension-list.pb',
    );
    final indexBody = GZipEncoder().encode(index.writeToBuffer());
    final listBody = GZipEncoder().encode(
      repo_pb.ExtensionList(extensions: [_protoExtension()]).writeToBuffer(),
    );

    final result = await fetchRepositoryIndex(
      'https://repo.example/index.pb',
      client: MockClient((request) async {
        return request.url.path == '/index.pb'
            ? http.Response.bytes(indexBody, 200)
            : http.Response.bytes(listBody, 200);
      }),
    );

    expect(result.name, 'Repo Terpisah');
    expect(result.sources.single.name, 'Ikiru');
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

  test('repository besar disimpan gzip dan bisa dibaca kembali', () {
    final sources = List.generate(
      2022,
      (index) => RepoSource(
        id: '${1707768678643970000 + index}',
        name: 'Source $index',
        hue: index % 360,
        lang: index.isEven ? 'EN' : 'ID',
        baseUrl: 'https://source-$index.example/manga',
        pkg: 'eu.kanade.tachiyomi.extension.en.source$index',
        apk: 'https://cdn.example/source-$index-v1.4.$index.apk',
        version: '1.4.$index',
        versionCode: index,
      ),
    );
    final repository = ComicRepository(
      id: 'besar',
      name: 'Repo Besar',
      url: 'https://repo.example/index.pb',
      sources: sources,
    );

    final map = repository.toMap();
    final restored = ComicRepository.fromMap('besar', map);

    expect(map, isNot(contains('sources')));
    expect(map['sourcesGzip'], isA<String>());
    expect((map['sourcesGzip'] as String).length, lessThan(900000));
    expect(restored.sources, hasLength(2022));
    expect(restored.sources[1400].pkg, sources[1400].pkg);
    expect(restored.sources[1400].baseUrl, sources[1400].baseUrl);
  });

  test('dokumen repository lama dan gzip rusak tetap terbaca', () {
    final restored = ComicRepository.fromMap('lama', {
      'name': 'Repo Lama',
      'url': 'https://repo.example/index.json',
      'sourcesGzip': 'bukan-base64',
      'sources': [
        {'id': 'source-lama', 'name': 'Source Lama', 'hue': 10, 'lang': 'ID'},
      ],
    });

    expect(restored.sources.single.name, 'Source Lama');
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

  test('merge repository membawa nama dan domain lama sebagai alias', () {
    const package = 'eu.kanade.tachiyomi.extension.id.sumber';
    final merged = mergeRepositorySources(
      const [
        RepoSource(
          id: 'stable-id',
          name: 'Nama Lama',
          hue: 10,
          lang: 'ID',
          baseUrl: 'https://domain-lama.test',
          pkg: package,
          versionCode: 1,
        ),
      ],
      const [
        RepoSource(
          id: 'stable-id',
          name: 'Nama Baru',
          hue: 10,
          lang: 'ID',
          baseUrl: 'https://domain-baru.test',
          pkg: package,
          versionCode: 2,
        ),
      ],
    );

    expect(merged.single.name, 'Nama Baru');
    expect(merged.single.baseUrl, 'https://domain-baru.test');
    expect(merged.single.nameAliases, contains('Nama Lama'));
    expect(merged.single.baseUrlAliases, contains('https://domain-lama.test'));
    expect(merged.single.versionCode, 2);
  });

  test('index pemberitahuan update app tidak menghapus cache repository', () {
    const current = [
      RepoSource(
        id: 'sumber-lama',
        name: 'Sumber Lama',
        hue: 10,
        lang: 'ID',
        baseUrl: 'https://sumber.test',
      ),
    ];
    const notice = [
      RepoSource(
        id: 'notice',
        name: 'Update to Mihon 0.20.1+',
        hue: 20,
        lang: 'ALL',
        baseUrl: 'https://mihon.app',
      ),
    ];

    expect(mergeRepositorySources(current, notice), current);
  });

  test(
    'penyusutan ekstrem repository mempertahankan sumber cache yang hilang',
    () {
      final current = List.generate(
        30,
        (index) => RepoSource(
          id: 'source-$index',
          name: 'Source $index',
          hue: index,
          lang: 'EN',
          baseUrl: 'https://source-$index.test',
        ),
      );
      const incoming = [
        RepoSource(
          id: 'source-0',
          name: 'Source 0',
          hue: 0,
          lang: 'EN',
          baseUrl: 'https://source-0-new.test',
        ),
      ];

      final merged = mergeRepositorySources(current, incoming);

      expect(merged, hasLength(30));
      expect(merged.first.baseUrl, 'https://source-0-new.test');
    },
  );

  test('findRepoSource mencocokkan repo source lewat nama, url, dan alias', () {
    const repositories = [
      ComicRepository(
        id: 'r1',
        name: 'Repo Satu',
        url: 'https://repo.test/index.json',
        sources: [
          RepoSource(
            id: 's-asura',
            name: 'Asura Scans',
            hue: 200,
            lang: 'EN',
            baseUrl: 'https://asuracomic.net',
            pkg: 'eu.kanade.tachiyomi.extension.en.asurascans',
            nameAliases: ['AsuraToons'],
            baseUrlAliases: ['https://asuratoons.com'],
          ),
        ],
      ),
    ];

    // Cocok lewat URL alias
    final matchByUrlAlias = findRepoSource(
      repositories: repositories,
      urlAliases: ['https://asuratoons.com'],
    );
    expect(matchByUrlAlias?.source.id, 's-asura');

    // Cocok lewat nama alias
    final matchByNameAlias = findRepoSource(
      repositories: repositories,
      name: 'AsuraToons',
    );
    expect(matchByNameAlias?.source.id, 's-asura');

    // Cocok lewat fuzzy title (spasi / simbol berbeda)
    final matchByFuzzy = findRepoSource(
      repositories: repositories,
      name: 'asura-scans',
    );
    expect(matchByFuzzy?.source.id, 's-asura');
  });
}

repo_pb.Extension _protoExtension() => repo_pb.Extension(
  name: 'Ikiru',
  packageName: 'eu.kanade.tachiyomi.extension.id.ikiru',
  resources: repo_pb.Resources(
    apkUrl: 'https://cdn.example/tachiyomi-id.ikiru-v1.4.30.apk',
  ),
  versionCode: Int64(30),
  versionName: '1.4.30',
  sources: [
    repo_pb.Source(
      id: Int64.parseInt('1707768678643970514'),
      name: 'Ikiru',
      language: 'id',
      homeUrl: 'https://ikiru.example',
      mirrorUrls: ['https://mirror.ikiru.example'],
    ),
  ],
);
