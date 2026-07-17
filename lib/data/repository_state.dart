import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'firestore_scope.dart';

/// Sumber yang tersedia dari sebuah repository.
class RepoSource {
  const RepoSource({
    required this.id,
    required this.name,
    required this.hue,
    required this.lang,
    this.baseUrl,
    this.pkg,
    this.apk,
    this.version,
    this.versionCode,
    this.parserKind,
  });

  final String id;
  final String name;
  final int hue;
  final String lang;
  final String? baseUrl;
  final String? pkg;
  final String? apk;
  final String? version;
  final int? versionCode;
  final String? parserKind;

  String get initial => name.isEmpty ? '?' : name[0];

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'hue': hue,
    'lang': lang,
    'baseUrl': ?baseUrl,
    'pkg': ?pkg,
    'apk': ?apk,
    'version': ?version,
    'versionCode': ?versionCode,
    'parserKind': ?parserKind,
  };

  factory RepoSource.fromMap(Map<String, dynamic> map) => RepoSource(
    id: map['id'] as String? ?? '',
    name: map['name'] as String? ?? '',
    hue: (map['hue'] as num?)?.toInt() ?? 0,
    lang: map['lang'] as String? ?? '',
    baseUrl: map['baseUrl'] as String?,
    pkg: map['pkg'] as String?,
    apk: map['apk'] as String?,
    version: map['version'] as String?,
    versionCode: (map['versionCode'] as num?)?.toInt(),
    parserKind: map['parserKind'] as String?,
  );
}

/// Repository = satu link index berisi banyak sumber.
class ComicRepository {
  const ComicRepository({
    required this.id,
    required this.name,
    required this.url,
    required this.sources,
  });

  final String id;
  final String name;
  final String url;
  final List<RepoSource> sources;

  ComicRepository copyWith({
    String? name,
    String? url,
    List<RepoSource>? sources,
  }) => ComicRepository(
    id: id,
    name: name ?? this.name,
    url: url ?? this.url,
    sources: sources ?? this.sources,
  );

  /// Mapping ke `users/{uid}/repositories/{repoId}` — `sources` di-embed
  /// (bukan subcollection) sesuai docs/DATABASE.md.
  Map<String, dynamic> toMap() => {
    'name': name,
    'url': url,
    'sources': sources.map((s) => s.toMap()).toList(),
  };

  factory ComicRepository.fromMap(String id, Map<String, dynamic> map) =>
      ComicRepository(
        id: id,
        name: map['name'] as String? ?? '',
        url: map['url'] as String? ?? '',
        sources: (map['sources'] as List<dynamic>? ?? [])
            .map((s) => RepoSource.fromMap(Map<String, dynamic>.from(s as Map)))
            .toList(),
      );
}

/// Data demo — dipakai saat belum login/Firebase tak tersedia.
const _seedRepositories = [
  ComicRepository(
    id: 'rp1',
    name: 'Komunitas Scan ID',
    url: 'repo.komunitasscan.example/index.json',
    sources: [
      RepoSource(id: 'rps1', name: 'NusaScans', hue: 210, lang: 'ID'),
      RepoSource(id: 'rps2', name: 'KomikRaya', hue: 150, lang: 'ID'),
      RepoSource(id: 'rps3', name: 'MangaLintang', hue: 30, lang: 'ID'),
    ],
  ),
  ComicRepository(
    id: 'rp2',
    name: 'Global Scan Hub',
    url: 'globalscanhub.example/repo.json',
    sources: [
      RepoSource(id: 'rps4', name: 'InkVerse', hue: 260, lang: 'EN'),
      RepoSource(id: 'rps5', name: 'Duniakomik', hue: 340, lang: 'EN'),
      RepoSource(id: 'rps6', name: 'ToonForge', hue: 190, lang: 'JP'),
      RepoSource(id: 'rps7', name: 'HanComics', hue: 10, lang: 'KR'),
    ],
  ),
];

class RepositoryIndexResult {
  const RepositoryIndexResult({required this.name, required this.sources});

  final String name;
  final List<RepoSource> sources;
}

class RepositoryIndexException implements Exception {
  const RepositoryIndexException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RepositoryRefreshResult {
  const RepositoryRefreshResult({required this.updated, required this.failed});

  final int updated;
  final int failed;
}

class RepoSourceMatch {
  const RepoSourceMatch({required this.repository, required this.source});

  final ComicRepository repository;
  final RepoSource source;

  String? get apkUrl => repositoryApkUrl(repository.url, source.apk);
}

String normalizeRepositoryUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed.startsWith('http') ? trimmed : 'https://$trimmed';
}

String? repositoryApkUrl(String repositoryUrl, String? apk) {
  if (apk == null || apk.trim().isEmpty) return null;
  final trimmedApk = apk.trim();
  if (trimmedApk.startsWith('http')) return trimmedApk;
  final url = normalizeRepositoryUrl(repositoryUrl);
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final segments = uri.pathSegments;
  if (segments.isEmpty) return uri.resolve('apk/$trimmedApk').toString();
  final baseSegments = segments.last.contains('.')
      ? segments.sublist(0, segments.length - 1)
      : segments;
  return uri
      .replace(pathSegments: [...baseSegments, 'apk', trimmedApk])
      .toString();
}

bool repositoryUpdateAvailable({
  required RepoSource source,
  required int installedVersionCode,
  String? installedVersionName,
}) {
  final code = source.versionCode;
  if (code != null && installedVersionCode > 0) {
    return code > installedVersionCode;
  }
  final available = _versionParts(source.version);
  final installed = _versionParts(installedVersionName);
  if (available.isEmpty || installed.isEmpty) return false;
  final length = math.max(available.length, installed.length);
  for (var index = 0; index < length; index++) {
    final a = index < available.length ? available[index] : 0;
    final b = index < installed.length ? installed[index] : 0;
    if (a != b) return a > b;
  }
  return false;
}

List<int> _versionParts(String? value) => RegExp(
  r'\d+',
).allMatches(value ?? '').map((match) => int.parse(match.group(0)!)).toList();

RepoSourceMatch? findRepoSourceForUrl(
  String rawUrl,
  List<ComicRepository> repositories,
) {
  final host = _hostOf(rawUrl);
  if (host == null) return null;
  RepoSourceMatch? fallback;
  for (final repository in repositories) {
    for (final source in repository.sources) {
      final sourceHost = _hostOf(source.baseUrl ?? '');
      if (sourceHost == null) continue;
      if (host == sourceHost) {
        return RepoSourceMatch(repository: repository, source: source);
      }
      if (_sameDomain(host, sourceHost)) {
        fallback ??= RepoSourceMatch(repository: repository, source: source);
      }
    }
  }
  return fallback;
}

RepoSourceMatch? findRepoSource({
  required List<ComicRepository> repositories,
  String? rawUrl,
  String? packageName,
  String? sourceId,
}) {
  if (sourceId != null || packageName != null) {
    RepoSourceMatch? packageFallback;
    for (final repository in repositories) {
      for (final source in repository.sources) {
        final packageMatches = packageName == null || source.pkg == packageName;
        if (!packageMatches) continue;
        if (sourceId != null && source.id == sourceId) {
          return RepoSourceMatch(repository: repository, source: source);
        }
        packageFallback ??= RepoSourceMatch(
          repository: repository,
          source: source,
        );
      }
    }
    if (sourceId == null && packageFallback != null) return packageFallback;
  }
  if (rawUrl == null) return null;
  return findRepoSourceForUrl(rawUrl, repositories);
}

String? _hostOf(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  final uri = Uri.tryParse(value.startsWith('http') ? value : 'https://$value');
  final host = uri?.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  return host == null || host.isEmpty ? null : host;
}

bool _sameDomain(String a, String b) =>
    a == b || a.endsWith('.$b') || b.endsWith('.$a');

Future<RepositoryIndexResult> fetchRepositoryIndex(
  String rawUrl, {
  http.Client? client,
}) async {
  final url = normalizeRepositoryUrl(rawUrl);
  final httpClient = client ?? http.Client();
  late final http.Response response;
  try {
    response = await httpClient.get(
      Uri.parse(url),
      headers: const {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'application/json,text/plain,*/*',
      },
    );
  } catch (e) {
    throw RepositoryIndexException('Gagal menghubungi repository: $e');
  }
  if (response.statusCode != 200) {
    throw RepositoryIndexException(
      'Repository mengembalikan status ${response.statusCode}.',
    );
  }

  final decoded = jsonDecode(response.body);
  final extensions = switch (decoded) {
    final List<dynamic> list => list,
    final Map<String, dynamic> map when map['extensions'] is List =>
      map['extensions'] as List<dynamic>,
    final Map<String, dynamic> map when map['data'] is List =>
      map['data'] as List<dynamic>,
    _ => throw const RepositoryIndexException(
      'Format repository tidak dikenali.',
    ),
  };

  final sources = <RepoSource>[];
  final seen = <String>{};
  for (final extRaw in extensions) {
    if (extRaw is! Map) continue;
    final ext = Map<String, dynamic>.from(extRaw);
    final pkg = ext['pkg'] as String?;
    final apk = ext['apk'] as String?;
    final version = ext['version'] as String?;
    final versionCode = (ext['code'] as num?)?.toInt();
    final extName = (ext['name'] as String?)?.replaceFirst('Tachiyomi: ', '');
    final extLang = _normalizeRepoLang(ext['lang'] as String?);
    final rawSources = ext['sources'];
    if (rawSources is List) {
      for (final sourceRaw in rawSources) {
        if (sourceRaw is! Map) continue;
        final source = Map<String, dynamic>.from(sourceRaw);
        final name = source['name'] as String? ?? extName;
        final baseUrl = source['baseUrl'] as String?;
        if (name == null || name.trim().isEmpty) continue;
        final id = '${source['id'] ?? '$pkg:$name:$baseUrl'}';
        final lang = _normalizeRepoLang(source['lang'] as String?) ?? extLang;
        final key = '$id|$baseUrl|$lang';
        if (!seen.add(key)) continue;
        sources.add(
          RepoSource(
            id: id,
            name: name,
            hue: _stableHue('$pkg:$id:$name'),
            lang: lang ?? 'ALL',
            baseUrl: baseUrl,
            pkg: pkg,
            apk: apk,
            version: version,
            versionCode: versionCode,
            parserKind: pkg == null
                ? (baseUrl == null ? null : 'universal-html')
                : 'extension-runtime:$pkg',
          ),
        );
      }
    } else if (extName != null) {
      final key = '$pkg|$extName|$extLang';
      if (!seen.add(key)) continue;
      sources.add(
        RepoSource(
          id: pkg ?? extName,
          name: extName,
          hue: _stableHue('$pkg:$extName'),
          lang: extLang ?? 'ALL',
          pkg: pkg,
          apk: apk,
          version: version,
          versionCode: versionCode,
        ),
      );
    }
  }
  if (sources.isEmpty) {
    throw const RepositoryIndexException(
      'Repository valid, tapi tidak ada sumber yang bisa dibaca dari index.',
    );
  }
  sources.sort((a, b) {
    final byLang = a.lang.compareTo(b.lang);
    if (byLang != 0) return byLang;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return RepositoryIndexResult(name: _repoNameFromUrl(url), sources: sources);
}

String _repoNameFromUrl(String url) {
  final uri = Uri.tryParse(url);
  final host = uri?.host.replaceFirst('raw.githubusercontent.com', 'GitHub');
  final segments = uri?.pathSegments ?? const <String>[];
  if (segments.length >= 2) return '${segments[0]}/${segments[1]}';
  return host?.isEmpty ?? true ? 'Repository' : host!;
}

String? _normalizeRepoLang(String? lang) {
  final value = lang?.trim().toLowerCase();
  return switch (value) {
    null || '' => null,
    'all' || 'multi' => 'ALL',
    'id' || 'in' => 'ID',
    'en' => 'EN',
    'ja' || 'jp' => 'JP',
    'ko' || 'kr' => 'KR',
    'zh' || 'zh-hans' || 'zh-hant' || 'cn' => 'CN',
    _ => value.toUpperCase(),
  };
}

int _stableHue(String seed) {
  var hash = 0;
  for (final unit in seed.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return 20 + math.Random(hash).nextInt(320);
}

class RepositoriesNotifier extends Notifier<List<ComicRepository>> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  CollectionReference<Map<String, dynamic>>? get _col =>
      FirestoreScope.collection('repositories');

  @override
  List<ComicRepository> build() {
    ref.onDispose(() => _sub?.cancel());
    final col = _col;
    if (col == null) return _seedRepositories;
    _sub = col.snapshots().listen((snap) {
      state = snap.docs
          .map((d) => ComicRepository.fromMap(d.id, d.data()))
          .toList();
    });
    return const [];
  }

  Future<void> add(ComicRepository repo) async {
    final col = _col;
    if (col == null) {
      state = [...state, repo];
      return;
    }
    await col.doc(repo.id).set({
      ...repo.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> update(
    String id, {
    String? name,
    String? url,
    List<RepoSource>? sources,
  }) async {
    final col = _col;
    if (col == null) {
      state = [
        for (final r in state)
          if (r.id == id)
            r.copyWith(name: name, url: url, sources: sources)
          else
            r,
      ];
      return;
    }
    await col.doc(id).update({
      'name': ?name,
      'url': ?url,
      if (sources != null) 'sources': sources.map((s) => s.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> remove(String id) async {
    final col = _col;
    if (col == null) {
      state = state.where((r) => r.id != id).toList();
      return;
    }
    await col.doc(id).delete();
  }

  Future<RepositoryRefreshResult> refreshAll() async {
    var updated = 0;
    var failed = 0;
    for (final repository in List<ComicRepository>.of(state)) {
      try {
        final result = await fetchRepositoryIndex(repository.url);
        await update(
          repository.id,
          name: repository.name,
          sources: result.sources,
        );
        updated++;
      } catch (_) {
        failed++;
      }
    }
    return RepositoryRefreshResult(updated: updated, failed: failed);
  }
}

final repositoriesProvider =
    NotifierProvider<RepositoriesNotifier, List<ComicRepository>>(
      RepositoriesNotifier.new,
    );

/// `users/{uid}/settings/app` (field `activeLangs`) — bahasa yang
/// diaktifkan untuk pengelompokan repository (default prototipe).
class ActiveLangsNotifier extends Notifier<List<String>> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  static const _seed = ['ALL', 'ID', 'EN'];

  DocumentReference<Map<String, dynamic>>? get _doc =>
      FirestoreScope.collection('settings')?.doc('app');

  @override
  List<String> build() {
    ref.onDispose(() => _sub?.cancel());
    final doc = _doc;
    if (doc == null) return _seed;
    _sub = doc.snapshots().listen((snap) {
      final langs = snap.data()?['activeLangs'] as List<dynamic>?;
      state = langs == null ? _seed : langs.cast<String>();
    });
    return _seed;
  }

  Future<void> toggle(String lang) async {
    final next = state.contains(lang)
        ? state.where((l) => l != lang).toList()
        : [...state, lang];
    final doc = _doc;
    if (doc == null) {
      state = next;
      return;
    }
    await doc.set({'activeLangs': next}, SetOptions(merge: true));
  }
}

final activeLangsProvider = NotifierProvider<ActiveLangsNotifier, List<String>>(
  ActiveLangsNotifier.new,
);
