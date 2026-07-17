import 'package:flutter/services.dart';

import 'source_session_store.dart';

class WebViewSession {
  const WebViewSession({required this.url, this.cookie, this.userAgent});

  final String url;
  final String? cookie;
  final String? userAgent;

  factory WebViewSession.fromMap(Map<Object?, Object?> map) => WebViewSession(
    url: map['url'] as String? ?? '',
    cookie: map['cookie'] as String?,
    userAgent: map['userAgent'] as String?,
  );
}

class ExtensionRuntimeInfo {
  const ExtensionRuntimeInfo({
    required this.platform,
    required this.apiVersion,
    required this.available,
    required this.message,
    required this.capabilities,
  });

  final String platform;
  final int apiVersion;
  final bool available;
  final String message;
  final ExtensionRuntimeCapabilities capabilities;

  factory ExtensionRuntimeInfo.fromMap(Map<Object?, Object?> map) {
    final rawCapabilities = map['capabilities'];
    return ExtensionRuntimeInfo(
      platform: map['platform'] as String? ?? 'unknown',
      apiVersion: (map['apiVersion'] as num?)?.toInt() ?? 0,
      available: map['available'] as bool? ?? false,
      message: map['message'] as String? ?? '',
      capabilities: ExtensionRuntimeCapabilities.fromMap(
        rawCapabilities is Map
            ? Map<Object?, Object?>.from(rawCapabilities)
            : const {},
      ),
    );
  }
}

class ExtensionRuntimeCapabilities {
  const ExtensionRuntimeCapabilities({
    required this.packageDiscovery,
    required this.apkClassLoading,
    required this.tachiyomiSourceApi,
    required this.tachiyomiSourceFactory,
    required this.networkBridge,
  });

  final bool packageDiscovery;
  final bool apkClassLoading;
  final bool tachiyomiSourceApi;
  final bool tachiyomiSourceFactory;
  final bool networkBridge;

  factory ExtensionRuntimeCapabilities.fromMap(Map<Object?, Object?> map) =>
      ExtensionRuntimeCapabilities(
        packageDiscovery: map['packageDiscovery'] as bool? ?? false,
        apkClassLoading: map['apkClassLoading'] as bool? ?? false,
        tachiyomiSourceApi: map['tachiyomiSourceApi'] as bool? ?? false,
        tachiyomiSourceFactory: map['tachiyomiSourceFactory'] as bool? ?? false,
        networkBridge: map['networkBridge'] as bool? ?? false,
      );
}

class InstalledExtensionPackage {
  const InstalledExtensionPackage({
    required this.packageName,
    required this.name,
    required this.versionCode,
    this.versionName,
    this.extensionClass,
    this.sourceDir,
    this.installed = true,
  });

  final String packageName;
  final String name;
  final int versionCode;
  final String? versionName;
  final String? extensionClass;
  final String? sourceDir;
  final bool installed;

  factory InstalledExtensionPackage.fromMap(Map<Object?, Object?> map) =>
      InstalledExtensionPackage(
        packageName: map['packageName'] as String? ?? '',
        name: map['name'] as String? ?? '',
        versionName: map['versionName'] as String?,
        extensionClass: map['extensionClass'] as String?,
        sourceDir: map['sourceDir'] as String?,
        versionCode: (map['versionCode'] as num?)?.toInt() ?? 0,
        installed: map['installed'] as bool? ?? true,
      );
}

class InstalledExtensionSourceMatch {
  const InstalledExtensionSourceMatch({
    required this.package,
    required this.source,
  });

  final InstalledExtensionPackage package;
  final ExtensionSourceInfo source;
}

class ExtensionSourceInfo {
  const ExtensionSourceInfo({
    required this.packageName,
    required this.sourceDir,
    required this.extensionClass,
    required this.className,
    required this.name,
    required this.baseUrl,
    required this.lang,
    required this.id,
    required this.supportsLatest,
    required this.superclasses,
  });

  final String packageName;
  final String sourceDir;
  final String extensionClass;
  final String className;
  final String name;
  final String baseUrl;
  final String lang;
  final int id;
  final bool supportsLatest;
  final List<String> superclasses;

  factory ExtensionSourceInfo.fromMap(Map<Object?, Object?> map) =>
      ExtensionSourceInfo(
        packageName: map['packageName'] as String? ?? '',
        sourceDir: map['sourceDir'] as String? ?? '',
        extensionClass: map['extensionClass'] as String? ?? '',
        className: map['className'] as String? ?? '',
        name: map['name'] as String? ?? '',
        baseUrl: map['baseUrl'] as String? ?? '',
        lang: map['lang'] as String? ?? '',
        id: (map['id'] as num?)?.toInt() ?? 0,
        supportsLatest: map['supportsLatest'] as bool? ?? false,
        superclasses: (map['superclasses'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(),
      );
}

class ExtensionManga {
  const ExtensionManga({
    required this.title,
    required this.url,
    this.thumbnailUrl,
    this.headers = const {},
    this.author,
    this.artist,
    this.description,
    this.genre,
    this.status = 0,
  });

  final String title;
  final String url;
  final String? thumbnailUrl;
  final Map<String, String> headers;
  final String? author;
  final String? artist;
  final String? description;
  final String? genre;
  final int status;

  factory ExtensionManga.fromMap(Map<Object?, Object?> map) => ExtensionManga(
    title: map['title'] as String? ?? '',
    url: map['url'] as String? ?? '',
    thumbnailUrl: map['thumbnailUrl'] as String?,
    headers: _stringMap(map['headers']),
    author: map['author'] as String?,
    artist: map['artist'] as String?,
    description: map['description'] as String?,
    genre: map['genre'] as String?,
    status: (map['status'] as num?)?.toInt() ?? 0,
  );
}

class ExtensionChapter {
  const ExtensionChapter({
    required this.url,
    required this.name,
    required this.dateUpload,
    this.scanlator,
  });

  final String url;
  final String name;
  final int dateUpload;
  final String? scanlator;

  factory ExtensionChapter.fromMap(Map<Object?, Object?> map) =>
      ExtensionChapter(
        url: map['url'] as String? ?? '',
        name: map['name'] as String? ?? '',
        dateUpload: (map['dateUpload'] as num?)?.toInt() ?? 0,
        scanlator: map['scanlator'] as String?,
      );
}

class ExtensionPage {
  const ExtensionPage({
    required this.index,
    required this.url,
    required this.imageUrl,
    this.headers = const {},
  });

  final int index;
  final String url;
  final String imageUrl;
  final Map<String, String> headers;

  factory ExtensionPage.fromMap(Map<Object?, Object?> map) => ExtensionPage(
    index: (map['index'] as num?)?.toInt() ?? 0,
    url: map['url'] as String? ?? '',
    imageUrl: map['imageUrl'] as String? ?? '',
    headers: _stringMap(map['headers']),
  );
}

class ExtensionMangaPage {
  const ExtensionMangaPage({
    required this.source,
    required this.mangas,
    required this.hasNextPage,
  });

  final ExtensionSourceInfo source;
  final List<ExtensionManga> mangas;
  final bool hasNextPage;

  factory ExtensionMangaPage.fromMap(Map<Object?, Object?> map) {
    final rawSource = map['source'];
    return ExtensionMangaPage(
      source: ExtensionSourceInfo.fromMap(
        rawSource is Map ? Map<Object?, Object?>.from(rawSource) : const {},
      ),
      mangas: (map['mangas'] as List<dynamic>? ?? const [])
          .whereType<Map<Object?, Object?>>()
          .map(ExtensionManga.fromMap)
          .toList(),
      hasNextPage: map['hasNextPage'] as bool? ?? false,
    );
  }
}

/// Jembatan Flutter -> native runtime untuk fitur extension Tachiyomi-style.
///
/// Android sekarang sudah punya POC DexClassLoader + compatibility layer
/// minimal untuk extension `HttpSource` sederhana. Tidak semua extension akan
/// langsung jalan karena beberapa butuh API/dependency Tachiyomi yang belum
/// dipetakan.
class ExtensionRuntimeBridge {
  const ExtensionRuntimeBridge({
    MethodChannel channel = const MethodChannel(_channelName),
  }) : this._(channel);

  const ExtensionRuntimeBridge._(this._channel);

  static const _channelName = 'kizen/extension_runtime';

  final MethodChannel _channel;

  Future<ExtensionRuntimeInfo> runtimeInfo() async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>('runtimeInfo');
    return ExtensionRuntimeInfo.fromMap(raw ?? const {});
  }

  Future<WebViewSession> readWebViewSession(String url) async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      'readWebViewSession',
      {'url': url},
    );
    return WebViewSession.fromMap(raw ?? const {});
  }

  Future<List<InstalledExtensionPackage>> listInstalledExtensions() async {
    final raw = await _channel.invokeListMethod<Object?>(
      'listInstalledExtensions',
    );
    return (raw ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map(InstalledExtensionPackage.fromMap)
        .where((extension) => extension.packageName.isNotEmpty)
        .toList();
  }

  Future<ExtensionSourceInfo> inspectExtension(String packageName) async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      'inspectExtension',
      {'packageName': packageName},
    );
    return ExtensionSourceInfo.fromMap(raw ?? const {});
  }

  Future<List<ExtensionSourceInfo>> listExtensionSources(
    String packageName,
  ) async {
    final raw = await _channel.invokeListMethod<Object?>(
      'listExtensionSources',
      {'packageName': packageName},
    );
    return (raw ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map(ExtensionSourceInfo.fromMap)
        .where((source) => source.baseUrl.isNotEmpty)
        .toList();
  }

  Future<void> installExtensionApk({
    required String apkUrl,
    required String fileName,
  }) async {
    await _channel.invokeMethod<void>('installExtensionApk', {
      'apkUrl': apkUrl,
      'fileName': fileName,
    });
  }

  Future<void> uninstallExtensionPackage(String packageName) async {
    await _channel.invokeMethod<void>('uninstallExtensionPackage', {
      'packageName': packageName,
    });
  }

  Future<ExtensionMangaPage> fetchPopularFromExtension(
    String packageName, {
    int page = 1,
    String? sourceName,
    String? sourceLang,
    String? baseUrl,
  }) async {
    final raw = await _channel
        .invokeMapMethod<Object?, Object?>('fetchPopularFromExtension', {
          ..._sourceArguments(
            packageName,
            sourceName: sourceName,
            sourceLang: sourceLang,
            baseUrl: baseUrl,
          ),
          'page': page,
        });
    return ExtensionMangaPage.fromMap(raw ?? const {});
  }

  Future<ExtensionMangaPage> fetchLatestFromExtension(
    String packageName, {
    int page = 1,
    String? sourceName,
    String? sourceLang,
    String? baseUrl,
  }) async {
    final raw = await _channel
        .invokeMapMethod<Object?, Object?>('fetchLatestFromExtension', {
          ..._sourceArguments(
            packageName,
            sourceName: sourceName,
            sourceLang: sourceLang,
            baseUrl: baseUrl,
          ),
          'page': page,
        });
    return ExtensionMangaPage.fromMap(raw ?? const {});
  }

  Future<ExtensionMangaPage> fetchSearchFromExtension(
    String packageName, {
    required String query,
    int page = 1,
    String? sourceName,
    String? sourceLang,
    String? baseUrl,
  }) async {
    final raw = await _channel
        .invokeMapMethod<Object?, Object?>('fetchSearchFromExtension', {
          ..._sourceArguments(
            packageName,
            sourceName: sourceName,
            sourceLang: sourceLang,
            baseUrl: baseUrl,
          ),
          'query': query,
          'page': page,
        });
    return ExtensionMangaPage.fromMap(raw ?? const {});
  }

  Future<ExtensionManga> fetchMangaDetailsFromExtension(
    String packageName, {
    required String mangaUrl,
    required String title,
    String? thumbnailUrl,
    String? sourceName,
    String? sourceLang,
    String? baseUrl,
  }) async {
    final raw = await _channel
        .invokeMapMethod<Object?, Object?>('fetchMangaDetailsFromExtension', {
          ..._sourceArguments(
            packageName,
            sourceName: sourceName,
            sourceLang: sourceLang,
            baseUrl: baseUrl,
          ),
          'mangaUrl': mangaUrl,
          'title': title,
          'thumbnailUrl': thumbnailUrl,
        });
    return ExtensionManga.fromMap(raw ?? const {});
  }

  Future<List<ExtensionChapter>> fetchChapterListFromExtension(
    String packageName, {
    required String mangaUrl,
    required String title,
    String? thumbnailUrl,
    String? sourceName,
    String? sourceLang,
    String? baseUrl,
  }) async {
    final raw = await _channel
        .invokeListMethod<Object?>('fetchChapterListFromExtension', {
          ..._sourceArguments(
            packageName,
            sourceName: sourceName,
            sourceLang: sourceLang,
            baseUrl: baseUrl,
          ),
          'mangaUrl': mangaUrl,
          'title': title,
          'thumbnailUrl': thumbnailUrl,
        });
    return (raw ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map(ExtensionChapter.fromMap)
        .where((chapter) => chapter.url.isNotEmpty)
        .toList();
  }

  Future<List<ExtensionPage>> fetchPageListFromExtension(
    String packageName, {
    required String chapterUrl,
    required String chapterName,
    String? sourceName,
    String? sourceLang,
    String? baseUrl,
  }) async {
    final raw = await _channel
        .invokeListMethod<Object?>('fetchPageListFromExtension', {
          ..._sourceArguments(
            packageName,
            sourceName: sourceName,
            sourceLang: sourceLang,
            baseUrl: baseUrl,
          ),
          'chapterUrl': chapterUrl,
          'chapterName': chapterName,
        });
    return (raw ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map(ExtensionPage.fromMap)
        .where((page) => page.imageUrl.isNotEmpty)
        .toList();
  }
}

Future<InstalledExtensionSourceMatch?> findInstalledExtensionForUrl(
  String rawUrl, {
  ExtensionRuntimeBridge bridge = const ExtensionRuntimeBridge(),
}) async {
  final wantedHost = _normalizedHost(rawUrl);
  if (wantedHost == null) return null;
  final packages = await bridge.listInstalledExtensions();
  InstalledExtensionSourceMatch? domainMatch;
  for (final package in packages) {
    try {
      final sources = await bridge
          .listExtensionSources(package.packageName)
          .timeout(const Duration(seconds: 8));
      for (final source in sources) {
        final sourceHost = _normalizedHost(source.baseUrl);
        if (sourceHost == null) continue;
        final match = InstalledExtensionSourceMatch(
          package: package,
          source: source,
        );
        if (sourceHost == wantedHost) return match;
        if (sourceHost.endsWith('.$wantedHost') ||
            wantedHost.endsWith('.$sourceHost')) {
          domainMatch ??= match;
        }
      }
    } catch (_) {
      // One incompatible APK must not stop matching the other installed ones.
    }
  }
  return domainMatch;
}

String? _normalizedHost(String rawUrl) {
  final value = rawUrl.trim();
  if (value.isEmpty) return null;
  final uri = Uri.tryParse(
    value.startsWith('http://') || value.startsWith('https://')
        ? value
        : 'https://$value',
  );
  final host = uri?.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  return host == null || host.isEmpty ? null : host;
}

Map<String, Object?> _sourceArguments(
  String packageName, {
  String? sourceName,
  String? sourceLang,
  String? baseUrl,
}) => {
  'packageName': packageName,
  'sourceName': ?sourceName,
  'sourceLang': ?sourceLang,
  'baseUrl': ?baseUrl,
  'sessionHeaders': SourceSessionStore.headersFor(baseUrl ?? ''),
};

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) return const {};
  return value.map(
    (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
  )..removeWhere((key, value) => key.isEmpty || value.isEmpty);
}
