import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'firestore_scope.dart';
import 'generated/repository_index.pb.dart' as repo_pb;
import 'library_state.dart';
import 'sources_state.dart';

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
    this.nameAliases = const [],
    this.baseUrlAliases = const [],
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
  final List<String> nameAliases;
  final List<String> baseUrlAliases;

  String get initial => name.isEmpty ? '?' : name[0];

  bool matchesName(String value) =>
      name == value || nameAliases.any((alias) => alias == value);

  RepoSource copyWith({
    String? name,
    String? baseUrl,
    String? pkg,
    String? apk,
    String? version,
    int? versionCode,
    String? parserKind,
    List<String>? nameAliases,
    List<String>? baseUrlAliases,
  }) => RepoSource(
    id: id,
    name: name ?? this.name,
    hue: hue,
    lang: lang,
    baseUrl: baseUrl ?? this.baseUrl,
    pkg: pkg ?? this.pkg,
    apk: apk ?? this.apk,
    version: version ?? this.version,
    versionCode: versionCode ?? this.versionCode,
    parserKind: parserKind ?? this.parserKind,
    nameAliases: nameAliases ?? this.nameAliases,
    baseUrlAliases: baseUrlAliases ?? this.baseUrlAliases,
  );

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
    'nameAliases': nameAliases,
    'baseUrlAliases': baseUrlAliases,
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
    nameAliases:
        (map['nameAliases'] as List?)?.whereType<String>().toList() ?? const [],
    baseUrlAliases:
        (map['baseUrlAliases'] as List?)?.whereType<String>().toList() ??
        const [],
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

  /// Index modern bisa berisi ribuan source. Simpan sebagai JSON gzip supaya
  /// satu dokumen tetap jauh di bawah batas 1 MiB Firestore.
  Map<String, dynamic> toMap() => {
    'name': name,
    'url': url,
    'sourcesGzip': _encodeRepositorySources(sources),
  };

  factory ComicRepository.fromMap(String id, Map<String, dynamic> map) {
    final compressed = map['sourcesGzip'];
    final decoded = compressed is String
        ? _decodeRepositorySources(compressed)
        : null;
    final sources =
        decoded ??
        (map['sources'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map(
              (source) => RepoSource.fromMap(Map<String, dynamic>.from(source)),
            )
            .toList();
    return ComicRepository(
      id: id,
      name: map['name'] as String? ?? '',
      url: map['url'] as String? ?? '',
      sources: sources,
    );
  }
}

String _encodeRepositorySources(List<RepoSource> sources) {
  final json = jsonEncode(sources.map((source) => source.toMap()).toList());
  return base64Encode(GZipEncoder().encode(utf8.encode(json)));
}

List<RepoSource>? _decodeRepositorySources(String encoded) {
  try {
    final bytes = GZipDecoder().decodeBytes(
      base64Decode(encoded),
      verify: true,
    );
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! List) return null;
    return decoded
        .whereType<Map>()
        .map((source) => RepoSource.fromMap(Map<String, dynamic>.from(source)))
        .toList();
  } catch (_) {
    return null;
  }
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

/// Gabungkan index terbaru lewat identitas package + source ID. Nama dan
/// domain lama dibawa sebagai alias agar Library lama tetap resolve. Guard
/// penyusutan menjaga cache saat sebuah repo besar sementara berubah menjadi
/// index pemberitahuan migrasi berisi satu-dua extension saja.
List<RepoSource> mergeRepositorySources(
  List<RepoSource> current,
  List<RepoSource> incoming,
) {
  if (current.isEmpty) return incoming;
  if (incoming.isEmpty) return current;
  if (incoming.every(_isRepositoryNotice)) return current;

  final currentByKey = {
    for (final source in current) _repoSourceKey(source): source,
  };
  final mergedIncoming = <RepoSource>[];
  final incomingKeys = <String>{};
  for (final fresh in incoming) {
    final key = _repoSourceKey(fresh);
    incomingKeys.add(key);
    final previous = currentByKey[key];
    if (previous == null) {
      mergedIncoming.add(fresh);
      continue;
    }
    final nameAliases = <String>{
      ...previous.nameAliases,
      ...fresh.nameAliases,
      if (previous.name != fresh.name) previous.name,
    }.toList();
    final baseUrlAliases = <String>{
      ...previous.baseUrlAliases,
      ...fresh.baseUrlAliases,
      if (previous.baseUrl != null && previous.baseUrl != fresh.baseUrl)
        previous.baseUrl!,
    }.toList();
    mergedIncoming.add(
      fresh.copyWith(nameAliases: nameAliases, baseUrlAliases: baseUrlAliases),
    );
  }

  final shrankUnexpectedly =
      current.length >= 20 &&
      incoming.length < math.max(3, (current.length * 0.2).ceil());
  if (!shrankUnexpectedly) return mergedIncoming;
  return [
    ...mergedIncoming,
    for (final source in current)
      if (!incomingKeys.contains(_repoSourceKey(source))) source,
  ];
}

String _repoSourceKey(RepoSource source) {
  final pkg = source.pkg?.trim();
  if (pkg != null && pkg.isNotEmpty) return '$pkg|${source.id}';
  if (source.id.isNotEmpty) return 'id:${source.id}';
  return 'name:${source.name.toLowerCase()}|${source.lang}';
}

bool _isRepositoryNotice(RepoSource source) {
  final name = source.name.toLowerCase();
  return name.contains('outdated app') ||
      name.contains('update to mihon') ||
      name.contains('unsupported app');
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
      for (final candidate in [?source.baseUrl, ...source.baseUrlAliases]) {
        final sourceHost = _hostOf(candidate);
        if (sourceHost == null) continue;
        if (host == sourceHost) {
          return RepoSourceMatch(repository: repository, source: source);
        }
        if (_sameDomain(host, sourceHost)) {
          fallback ??= RepoSourceMatch(repository: repository, source: source);
        }
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
  String? name,
  List<String> nameAliases = const [],
  List<String> urlAliases = const [],
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

  // Cek URL utama dan semua URL aliases
  final candidateUrls = <String>[
    if (rawUrl != null && rawUrl.trim().isNotEmpty) rawUrl,
    ...urlAliases.where((u) => u.trim().isNotEmpty),
  ];
  for (final url in candidateUrls) {
    final match = findRepoSourceForUrl(url, repositories);
    if (match != null) return match;
  }

  // Cek Nama dan semua nama aliases (case-insensitive + normalized)
  final candidateNames = <String>[
    if (name != null && name.trim().isNotEmpty) name,
    ...nameAliases.where((n) => n.trim().isNotEmpty),
  ];
  if (candidateNames.isNotEmpty) {
    for (final repository in repositories) {
      for (final source in repository.sources) {
        for (final queryName in candidateNames) {
          if (source.matchesName(queryName) ||
              sameLibraryTitle(source.name, queryName)) {
            return RepoSourceMatch(repository: repository, source: source);
          }
        }
      }
    }
  }

  return null;
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
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw const RepositoryIndexException('Link repository tidak valid.');
  }
  final httpClient = client ?? http.Client();
  try {
    return await _fetchRepositoryIndexUri(uri, httpClient, visited: <String>{});
  } finally {
    if (client == null) httpClient.close();
  }
}

const _repositoryHeaders = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  'Accept':
      'application/protobuf,application/octet-stream,application/json,'
      'text/plain,*/*',
};

Future<RepositoryIndexResult> _fetchRepositoryIndexUri(
  Uri uri,
  http.Client client, {
  required Set<String> visited,
  String? fallbackName,
}) async {
  if (visited.length >= 6 || !visited.add(uri.toString())) {
    throw const RepositoryIndexException(
      'Repository mengarah ke indeks yang berulang.',
    );
  }

  final response = await _getRepository(uri, client);
  if (response.statusCode != 200) {
    final migrated = await _tryLegacyRepositoryMetadata(
      uri,
      client,
      visited: visited,
      fallbackName: fallbackName,
    );
    if (migrated != null) return migrated;
    throw RepositoryIndexException(
      'Repository mengembalikan status ${response.statusCode}.',
    );
  }

  final bytes = response.bodyBytes;
  if (_looksLikeJson(bytes)) {
    final decoded = _decodeRepositoryJson(bytes);
    if (decoded case final Map<String, dynamic> map) {
      final indexV2 = map['index_v2'];
      if (indexV2 is String && indexV2.trim().isNotEmpty) {
        return _fetchRepositoryIndexUri(
          uri.resolve(indexV2.trim()),
          client,
          visited: visited,
          fallbackName: _jsonRepositoryName(map) ?? fallbackName,
        );
      }
    }

    final extensions = _jsonExtensions(decoded);
    if (extensions == null) {
      throw const RepositoryIndexException(
        'Format repository JSON tidak dikenali.',
      );
    }
    final sources = _repoSourcesFromJson(extensions);
    if (sources.isEmpty) {
      throw const RepositoryIndexException(
        'Repository valid, tapi tidak ada sumber yang bisa dibaca dari index.',
      );
    }

    if (sources.every(_isRepositoryNotice)) {
      final migrated = await _tryLegacyRepositoryMetadata(
        uri,
        client,
        visited: visited,
        fallbackName: fallbackName,
      );
      if (migrated != null) return migrated;
    }
    return _repositoryResult(
      name: fallbackName ?? _repoNameFromUrl(uri.toString()),
      sources: sources,
    );
  }

  try {
    final index = repo_pb.Index.fromBuffer(_decodeGzipIfNeeded(bytes));
    final name = index.name.trim().isEmpty
        ? fallbackName ?? _repoNameFromUrl(uri.toString())
        : index.name.trim();
    final sources = switch (index.whichExtensions()) {
      repo_pb.Index_Extensions.extensionList => _repoSourcesFromProto(
        index.extensionList.extensions,
      ),
      repo_pb.Index_Extensions.extensionListUrl =>
        await _fetchExternalExtensionList(
          uri.resolve(index.extensionListUrl.trim()),
          client,
          visited: visited,
        ),
      repo_pb.Index_Extensions.notSet => const <RepoSource>[],
    };
    if (sources.isEmpty) {
      throw const RepositoryIndexException(
        'Repository valid, tapi tidak ada sumber yang bisa dibaca dari index.',
      );
    }
    return _repositoryResult(name: name, sources: sources);
  } on RepositoryIndexException {
    rethrow;
  } catch (e) {
    throw RepositoryIndexException(
      'Format repository Protobuf tidak dikenali: $e',
    );
  }
}

Future<http.Response> _getRepository(Uri uri, http.Client client) async {
  try {
    return await client.get(uri, headers: _repositoryHeaders);
  } catch (e) {
    throw RepositoryIndexException('Gagal menghubungi repository: $e');
  }
}

Future<RepositoryIndexResult?> _tryLegacyRepositoryMetadata(
  Uri uri,
  http.Client client, {
  required Set<String> visited,
  String? fallbackName,
}) async {
  final metadataUri = _legacyRepositoryMetadataUri(uri);
  if (metadataUri == null || visited.contains(metadataUri.toString())) {
    return null;
  }
  try {
    return await _fetchRepositoryIndexUri(
      metadataUri,
      client,
      visited: visited,
      fallbackName: fallbackName,
    );
  } on RepositoryIndexException {
    return null;
  }
}

Uri? _legacyRepositoryMetadataUri(Uri uri) {
  if (uri.pathSegments.isEmpty) return null;
  final file = uri.pathSegments.last.toLowerCase();
  if (!file.startsWith('index') || !file.endsWith('.json')) return null;
  return uri.replace(
    pathSegments: [
      ...uri.pathSegments.take(uri.pathSegments.length - 1),
      'repo.json',
    ],
    query: null,
    fragment: null,
  );
}

bool _looksLikeJson(List<int> bytes) {
  for (final byte in bytes) {
    if (byte == 0x20 || byte == 0x09 || byte == 0x0a || byte == 0x0d) {
      continue;
    }
    return byte == 0x5b || byte == 0x7b;
  }
  return false;
}

dynamic _decodeRepositoryJson(List<int> bytes) {
  try {
    return jsonDecode(utf8.decode(bytes));
  } catch (e) {
    throw RepositoryIndexException('JSON repository rusak: $e');
  }
}

String? _jsonRepositoryName(Map<String, dynamic> map) {
  final meta = map['meta'];
  if (meta is! Map) return null;
  final name = meta['name'];
  return name is String && name.trim().isNotEmpty ? name.trim() : null;
}

List<dynamic>? _jsonExtensions(dynamic decoded) => switch (decoded) {
  final List<dynamic> list => list,
  final Map<String, dynamic> map when map['extensions'] is List =>
    map['extensions'] as List<dynamic>,
  final Map<String, dynamic> map when map['data'] is List =>
    map['data'] as List<dynamic>,
  _ => null,
};

List<int> _decodeGzipIfNeeded(List<int> bytes) {
  if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
    return GZipDecoder().decodeBytes(bytes, verify: true);
  }
  return bytes;
}

Future<List<RepoSource>> _fetchExternalExtensionList(
  Uri uri,
  http.Client client, {
  required Set<String> visited,
}) async {
  if (visited.length >= 6 || !visited.add(uri.toString())) {
    throw const RepositoryIndexException(
      'Daftar extension repository mengarah berulang.',
    );
  }
  final response = await _getRepository(uri, client);
  if (response.statusCode != 200) {
    throw RepositoryIndexException(
      'Daftar extension mengembalikan status ${response.statusCode}.',
    );
  }
  final bytes = response.bodyBytes;
  if (_looksLikeJson(bytes)) {
    final extensions = _jsonExtensions(_decodeRepositoryJson(bytes));
    if (extensions == null) {
      throw const RepositoryIndexException(
        'Format daftar extension JSON tidak dikenali.',
      );
    }
    return _repoSourcesFromJson(extensions);
  }

  final decoded = _decodeGzipIfNeeded(bytes);
  try {
    final index = repo_pb.Index.fromBuffer(decoded);
    if (index.hasExtensionList()) {
      return _repoSourcesFromProto(index.extensionList.extensions);
    }
  } catch (_) {
    // URL eksternal biasanya berisi ExtensionList langsung, bukan Index.
  }
  try {
    final list = repo_pb.ExtensionList.fromBuffer(decoded);
    return _repoSourcesFromProto(list.extensions);
  } catch (e) {
    throw RepositoryIndexException(
      'Format daftar extension Protobuf tidak dikenali: $e',
    );
  }
}

List<RepoSource> _repoSourcesFromJson(List<dynamic> extensions) {
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
        final key = '$pkg|$id|$baseUrl|$lang';
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
  return sources;
}

List<RepoSource> _repoSourcesFromProto(Iterable<repo_pb.Extension> extensions) {
  final sources = <RepoSource>[];
  final seen = <String>{};
  for (final extension in extensions) {
    final pkg = extension.packageName.trim();
    final extName = extension.name.replaceFirst('Tachiyomi: ', '').trim();
    final apk = extension.hasResources()
        ? extension.resources.apkUrl.trim()
        : '';
    final version = extension.versionName.trim();
    final versionCode = extension.hasVersionCode()
        ? extension.versionCode.toInt()
        : null;

    if (extension.sources.isEmpty) {
      if (extName.isEmpty) continue;
      final id = pkg.isEmpty ? extName : pkg;
      if (!seen.add('$pkg|$id')) continue;
      sources.add(
        RepoSource(
          id: id,
          name: extName,
          hue: _stableHue('$pkg:$extName'),
          lang: 'ALL',
          pkg: pkg.isEmpty ? null : pkg,
          apk: apk.isEmpty ? null : apk,
          version: version.isEmpty ? null : version,
          versionCode: versionCode,
          parserKind: pkg.isEmpty ? null : 'extension-runtime:$pkg',
        ),
      );
      continue;
    }

    for (final source in extension.sources) {
      final name = source.name.trim().isEmpty ? extName : source.name.trim();
      if (name.isEmpty) continue;
      final mirrors = source.mirrorUrls
          .map((url) => url.trim())
          .where((url) => url.isNotEmpty)
          .toSet();
      final homeUrl = source.homeUrl.trim();
      final baseUrl = homeUrl.isNotEmpty
          ? homeUrl
          : mirrors.isEmpty
          ? null
          : mirrors.first;
      if (baseUrl != null) mirrors.remove(baseUrl);
      final id = source.hasId() ? source.id.toString() : '$pkg:$name:$baseUrl';
      final lang = _normalizeRepoLang(source.language) ?? 'ALL';
      if (!seen.add('$pkg|$id|$baseUrl|$lang')) continue;
      sources.add(
        RepoSource(
          id: id,
          name: name,
          hue: _stableHue('$pkg:$id:$name'),
          lang: lang,
          baseUrl: baseUrl,
          baseUrlAliases: mirrors.toList(),
          pkg: pkg.isEmpty ? null : pkg,
          apk: apk.isEmpty ? null : apk,
          version: version.isEmpty ? null : version,
          versionCode: versionCode,
          parserKind: pkg.isEmpty ? null : 'extension-runtime:$pkg',
        ),
      );
    }
  }
  return sources;
}

RepositoryIndexResult _repositoryResult({
  required String name,
  required List<RepoSource> sources,
}) {
  sources.sort((a, b) {
    final byLang = a.lang.compareTo(b.lang);
    if (byLang != 0) return byLang;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return RepositoryIndexResult(name: name, sources: sources);
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
      if (sources != null) 'sourcesGzip': _encodeRepositorySources(sources),
      if (sources != null) 'sources': FieldValue.delete(),
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
          sources: mergeRepositorySources(repository.sources, result.sources),
        );
        updated++;
      } catch (_) {
        failed++;
      }
    }
    if (updated > 0) {
      try {
        await ref.read(sourcesProvider.notifier).syncWithRepositories(state);
      } catch (_) {}
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
