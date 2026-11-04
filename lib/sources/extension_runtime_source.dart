import '../data/extension_runtime.dart';
import '../data/source_session_store.dart';
import '../data/source_url.dart';
import 'adaptive_source.dart';
import 'alternative_source_methods.dart';
import 'manga_source.dart';
import 'mangafire_source.dart';
import 'sveltekit_comic_source.dart';

class ExtensionRuntimeSource implements MangaSource {
  ExtensionRuntimeSource({
    required this.name,
    required this.packageName,
    required this.baseUrl,
    this.lang,
    ExtensionRuntimeBridge? bridge,
    MangaSource? fallback,
    AlternativeSourceMethods? alternatives,
    Iterable<String> fallbackBaseUrls = const [],
    List<MangaSource>? fallbackSources,
  }) : _bridge = bridge ?? const ExtensionRuntimeBridge(),
       _fallback =
           fallback ??
           _defaultFallback(
             name: name,
             baseUrl: baseUrl,
             lang: lang,
             fallbackBaseUrls: fallbackBaseUrls,
           ),
       _alternatives =
           alternatives ??
           AlternativeSourceMethods(name: name, baseUrl: baseUrl),
       _fallbackSources =
           fallbackSources ??
           _buildFallbackSources(
             name: name,
             baseUrl: baseUrl,
             fallbackBaseUrls: fallbackBaseUrls,
           );

  @override
  final String name;

  final String packageName;

  @override
  final String baseUrl;

  final String? lang;

  final ExtensionRuntimeBridge _bridge;
  final MangaSource _fallback;
  final AlternativeSourceMethods _alternatives;
  final List<MangaSource> _fallbackSources;
  final Map<int, String> _popularSignatures = {};

  static List<MangaSource> _buildFallbackSources({
    required String name,
    required String baseUrl,
    required Iterable<String> fallbackBaseUrls,
  }) {
    final primary = normalizeSourceBaseUrl(baseUrl);
    return [
      for (final fallback
          in fallbackBaseUrls
              .map(normalizeSourceBaseUrl)
              .where((url) => url.isNotEmpty && url != primary)
              .toSet())
        AdaptiveSource(name: name, baseUrl: fallback),
    ];
  }

  static MangaSource _defaultFallback({
    required String name,
    required String baseUrl,
    String? lang,
    Iterable<String> fallbackBaseUrls = const [],
  }) {
    final host = Uri.tryParse(baseUrl)?.host.toLowerCase();
    if (host == 'soulscans.asia' || host?.endsWith('.soulscans.asia') == true) {
      return SvelteKitComicSource(name: name, baseUrl: baseUrl);
    }
    if (host == 'mangafire.to' || host?.endsWith('.mangafire.to') == true) {
      return MangaFireSource(name: name, baseUrl: baseUrl, lang: lang);
    }
    return AdaptiveSource(
      name: name,
      baseUrl: baseUrl,
      fallbackBaseUrls: fallbackBaseUrls,
    );
  }

  bool get _prefersFreshCatalogLatest {
    final host = Uri.tryParse(baseUrl)?.host.toLowerCase();
    return host == 'soulscans.asia' ||
        host?.endsWith('.soulscans.asia') == true;
  }

  @override
  Future<SourceMangaPage> fetchPopular(int page) async {
    try {
      final result = await _bridge.fetchPopularFromExtension(
        packageName,
        page: page,
        sourceName: name,
        sourceLang: lang,
        baseUrl: baseUrl,
        sessionHeaders: SourceSessionStore.headersFor(baseUrl),
      );
      final mapped = _toPage(result);
      if (mapped.mangas.isNotEmpty) return _rememberPopular(page, mapped);
    } catch (_) {
      // Extension missing/incompatible/site changed: use adaptive HTML parser.
    }
    try {
      final result = await _fallback.fetchPopular(page);
      if (result.mangas.isNotEmpty) return _rememberPopular(page, result);
    } catch (_) {
      // Parser HTML utama gagal: lanjut ke parser alternatif.
    }
    try {
      final result = await _alternatives.fetchPopular(page);
      if (result.mangas.isNotEmpty) return _rememberPopular(page, result);
    } catch (_) {
      // Semua parser domain utama gagal: baru coba mirror/domain lama.
    }
    final mirrored = await _firstFallback(
      (source) => source.fetchPopular(page),
      (result) => result.mangas.isNotEmpty,
    );
    if (mirrored != null) return _rememberPopular(page, mirrored);
    throw _webViewError(baseUrl);
  }

  /// Beberapa extension mengembalikan section pendek (mis. 4 item homepage)
  /// sebagai hasil valid. Coba parser website hanya saat hasilnya kecil; kalau
  /// parser HTML menemukan katalog lebih besar, pakai hasil yang lebih lengkap
  /// tanpa mengganggu extension yang sudah mengembalikan daftar normal.
  Future<SourceMangaPage?> _largerLatestFallback(
    int page,
    SourceMangaPage current, {
    bool preferDistinctCatalog = false,
  }) async {
    final preferFreshCatalog = _prefersFreshCatalogLatest;
    if (!preferFreshCatalog &&
        !preferDistinctCatalog &&
        current.mangas.length >= 20) {
      return null;
    }
    try {
      final fallback = await _fallback.fetchLatest(page);
      if (fallback.mangas.isNotEmpty &&
          (preferFreshCatalog ||
              (preferDistinctCatalog &&
                  _catalogSignature(fallback) != _catalogSignature(current)) ||
              fallback.mangas.length > current.mangas.length)) {
        return fallback;
      }
    } catch (_) {
      // Coba rantai alternatif di bawah.
    }
    try {
      final alternative = await _alternatives.fetchLatest(page);
      if (alternative.mangas.isNotEmpty &&
          (preferFreshCatalog ||
              (preferDistinctCatalog &&
                  _catalogSignature(alternative) !=
                      _catalogSignature(current)) ||
              alternative.mangas.length > current.mangas.length)) {
        return alternative;
      }
    } catch (_) {
      // Pertahankan hasil extension yang sudah valid.
    }
    final mirrored = await _firstFallback(
      (source) => source.fetchLatest(page),
      (result) => result.mangas.isNotEmpty,
    );
    if (mirrored != null &&
        (preferFreshCatalog ||
            (preferDistinctCatalog &&
                _catalogSignature(mirrored) != _catalogSignature(current)) ||
            mirrored.mangas.length > current.mangas.length)) {
      return mirrored;
    }
    return null;
  }

  @override
  Future<SourceMangaPage> fetchLatest(int page) async {
    try {
      final result = await _bridge.fetchLatestFromExtension(
        packageName,
        page: page,
        sourceName: name,
        sourceLang: lang,
        baseUrl: baseUrl,
        sessionHeaders: SourceSessionStore.headersFor(baseUrl),
      );
      final mapped = _toPage(result);
      if (mapped.mangas.isNotEmpty) {
        final expanded = await _largerLatestFallback(
          page,
          mapped,
          preferDistinctCatalog: _matchesPopular(page, mapped),
        );
        return expanded ?? mapped;
      }
    } catch (_) {
      // Continue to fallback.
    }
    SourceMangaPage? duplicateFallback;
    try {
      final result = await _fallback.fetchLatest(page);
      if (result.mangas.isNotEmpty) {
        if (!_matchesPopular(page, result)) return result;
        duplicateFallback ??= result;
      }
    } catch (_) {
      // Lanjut ke parser alternatif.
    }
    try {
      final result = await _alternatives.fetchLatest(page);
      if (result.mangas.isNotEmpty) {
        if (!_matchesPopular(page, result)) return result;
        duplicateFallback ??= result;
      }
    } catch (_) {
      // Lanjut ke mirror/domain lama.
    }
    final mirrored = await _firstFallback(
      (source) => source.fetchLatest(page),
      (result) => result.mangas.isNotEmpty,
    );
    if (mirrored != null) {
      if (!_matchesPopular(page, mirrored)) return mirrored;
      duplicateFallback ??= mirrored;
    }
    if (duplicateFallback != null) return duplicateFallback;
    throw _webViewError(baseUrl);
  }

  @override
  Future<SourceMangaPage> fetchSearch(String query, int page) async {
    try {
      final result = await _bridge.fetchSearchFromExtension(
        packageName,
        query: query,
        page: page,
        sourceName: name,
        sourceLang: lang,
        baseUrl: baseUrl,
        sessionHeaders: SourceSessionStore.headersFor(baseUrl),
      );
      final mapped = _toPage(result);
      if (mapped.mangas.isNotEmpty) return mapped;
    } catch (_) {
      // Continue to fallback.
    }
    try {
      final result = await _fallback.fetchSearch(query, page);
      if (result.mangas.isNotEmpty) return result;
    } catch (_) {
      // Lanjut ke parser alternatif.
    }
    try {
      final result = await _alternatives.fetchSearch(query, page);
      if (result.mangas.isNotEmpty) return result;
    } catch (_) {
      // Lanjut ke mirror/domain lama.
    }
    final mirrored = await _firstFallback(
      (source) => source.fetchSearch(query, page),
      (result) => result.mangas.isNotEmpty,
    );
    if (mirrored != null) return mirrored;
    throw _webViewError(baseUrl);
  }

  @override
  Future<SourceMangaDetails> fetchMangaDetails(String mangaUrl) async {
    final currentMangaUrl = rebaseSourceUrl(mangaUrl, baseUrl);
    try {
      final manga = await _bridge.fetchMangaDetailsFromExtension(
        packageName,
        mangaUrl: currentMangaUrl,
        title: '',
        sourceName: name,
        sourceLang: lang,
        baseUrl: baseUrl,
        sessionHeaders: _sessionHeadersFor(currentMangaUrl),
      );
      final details = SourceMangaDetails(
        description: manga.description,
        author: manga.author,
        artist: manga.artist,
        genres: _splitGenres(manga.genre),
        status: _mapStatus(manga.status),
        thumbnailUrl: manga.thumbnailUrl,
      );
      if (details.description != null ||
          details.author != null ||
          details.thumbnailUrl != null ||
          details.genres.isNotEmpty) {
        return details;
      }
    } catch (_) {
      // Continue to fallback.
    }
    try {
      final details = await _fallback.fetchMangaDetails(currentMangaUrl);
      if (_hasDetails(details)) return details;
    } catch (_) {
      // Lanjut ke parser alternatif.
    }
    try {
      final details = await _alternatives.fetchMangaDetails(currentMangaUrl);
      if (_hasDetails(details)) return details;
    } catch (_) {
      // Lanjut ke mirror/domain lama.
    }
    final mirrored = await _firstFallbackWithUrl(
      currentMangaUrl,
      (source, url) => source.fetchMangaDetails(url),
      _hasDetails,
    );
    if (mirrored != null) return mirrored;
    throw _webViewError(currentMangaUrl);
  }

  @override
  Future<List<SourceChapter>> fetchChapterList(String mangaUrl) async {
    final currentMangaUrl = rebaseSourceUrl(mangaUrl, baseUrl);
    try {
      final chapters = await _bridge.fetchChapterListFromExtension(
        packageName,
        mangaUrl: currentMangaUrl,
        title: '',
        sourceName: name,
        sourceLang: lang,
        baseUrl: baseUrl,
        sessionHeaders: _sessionHeadersFor(currentMangaUrl),
      );
      final mapped = chapters
          .map(
            (chapter) => SourceChapter(
              url: chapter.url,
              name: chapter.name,
              dateUpload: chapter.dateUpload > 0
                  ? DateTime.fromMillisecondsSinceEpoch(chapter.dateUpload)
                  : null,
            ),
          )
          .toList();
      if (mapped.isNotEmpty) return mapped;
    } catch (_) {
      // Continue to fallback.
    }
    try {
      final chapters = await _fallback.fetchChapterList(currentMangaUrl);
      if (chapters.isNotEmpty) return chapters;
    } catch (_) {
      // Lanjut ke parser alternatif.
    }
    try {
      final chapters = await _alternatives.fetchChapterList(currentMangaUrl);
      if (chapters.isNotEmpty) return chapters;
    } catch (_) {
      // Lanjut ke mirror/domain lama.
    }
    final mirrored = await _firstFallbackWithUrl(
      currentMangaUrl,
      (source, url) => source.fetchChapterList(url),
      (chapters) => chapters.isNotEmpty,
    );
    if (mirrored != null) return mirrored;
    throw _webViewError(currentMangaUrl);
  }

  @override
  Future<List<SourcePage>> fetchPageList(String chapterUrl) async {
    final currentChapterUrl = rebaseSourceUrl(chapterUrl, baseUrl);
    try {
      final pages = await _bridge.fetchPageListFromExtension(
        packageName,
        chapterUrl: currentChapterUrl,
        chapterName: '',
        sourceName: name,
        sourceLang: lang,
        baseUrl: baseUrl,
        sessionHeaders: _sessionHeadersFor(currentChapterUrl),
      );
      if (pages.isNotEmpty) {
        return [
          for (var i = 0; i < pages.length; i++)
            SourcePage(
              index: i,
              imageUrl: pages[i].imageUrl,
              headers: _imageHeaders(pages[i]),
            ),
        ];
      }
    } catch (_) {
      // Continue to fallback.
    }
    try {
      final pages = await _fallback.fetchPageList(currentChapterUrl);
      if (pages.isNotEmpty) return pages;
    } catch (_) {
      // Lanjut ke parser alternatif.
    }
    try {
      final pages = await _alternatives.fetchPageList(currentChapterUrl);
      if (pages.isNotEmpty) return pages;
    } catch (_) {
      // Lanjut ke mirror/domain lama.
    }
    final mirrored = await _firstFallbackWithUrl(
      currentChapterUrl,
      (source, url) => source.fetchPageList(url),
      (pages) => pages.isNotEmpty,
    );
    if (mirrored != null) return mirrored;
    throw _webViewError(currentChapterUrl);
  }

  Future<T?> _firstFallback<T>(
    Future<T> Function(MangaSource source) request,
    bool Function(T result) usable,
  ) async {
    for (final source in _fallbackSources) {
      try {
        final result = await request(source);
        if (usable(result)) return result;
      } catch (_) {
        // Mirror ini gagal, lanjut ke mirror berikutnya.
      }
    }
    return null;
  }

  Future<T?> _firstFallbackWithUrl<T>(
    String rawUrl,
    Future<T> Function(MangaSource source, String url) request,
    bool Function(T result) usable,
  ) => _firstFallback(
    (source) => request(source, rebaseSourceUrl(rawUrl, source.baseUrl)),
    usable,
  );

  MangaSourceWebViewException _webViewError(
    String url,
  ) => MangaSourceWebViewException(
    message:
        'Semua metode parser $name sudah dicoba. Buka lewat WebView untuk melanjutkan.',
    url: rebaseSourceUrl(_absUrl(url), baseUrl),
  );

  bool _hasDetails(SourceMangaDetails details) =>
      details.description != null ||
      details.author != null ||
      details.artist != null ||
      details.genres.isNotEmpty ||
      details.thumbnailUrl != null ||
      details.status != SourceMangaStatus.unknown;

  Map<String, String> _imageHeaders(ExtensionPage page) {
    final headers = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Accept':
          'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
      'Accept-Language': 'id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7',
      'Sec-Fetch-Dest': 'image',
      'Sec-Fetch-Mode': 'no-cors',
      'Sec-Fetch-Site': _sameSite(page.imageUrl) ? 'same-site' : 'cross-site',
      'Referer': baseUrl,
      ...SourceSessionStore.headersFor(baseUrl),
      ...page.headers,
    };
    headers.removeWhere((key, value) => key.isEmpty || value.isEmpty);
    return headers;
  }

  String _absUrl(String url) =>
      rebaseSourceUrl(Uri.parse(baseUrl).resolve(url).toString(), baseUrl);

  Map<String, String> _sessionHeadersFor(String url) {
    final shouldSend = _sameSite(url);
    return {
      if (shouldSend) ...SourceSessionStore.headersFor(baseUrl),
      if (shouldSend) ...SourceSessionStore.headersFor(_absUrl(url)),
    };
  }

  bool _sameSite(String imageUrl) {
    final abs = _absUrl(imageUrl);
    final imageHost = Uri.tryParse(abs)?.host.toLowerCase();
    final baseHost =
        Uri.tryParse(normalizeSourceBaseUrl(baseUrl))?.host.toLowerCase();
    if (imageHost == null || baseHost == null || baseHost.isEmpty) return false;
    return imageHost == baseHost || imageHost.endsWith('.$baseHost');
  }

  SourceMangaPage _rememberPopular(int page, SourceMangaPage result) {
    _popularSignatures[page] = _catalogSignature(result);
    return result;
  }

  bool _matchesPopular(int page, SourceMangaPage result) {
    final popular = _popularSignatures[page];
    return popular != null && popular == _catalogSignature(result);
  }

  String _catalogSignature(SourceMangaPage page) => page.mangas
      .take(24)
      .map((manga) => manga.title.trim().toLowerCase())
      .join('\n');

  SourceMangaPage _toPage(ExtensionMangaPage result) => SourceMangaPage(
    mangas: [
      for (final manga in result.mangas)
        SourceManga(
          url: manga.url,
          title: manga.title,
          thumbnailUrl: manga.thumbnailUrl,
          headers: manga.headers,
        ),
    ],
    hasNextPage: result.hasNextPage,
  );

  List<String> _splitGenres(String? genre) => (genre ?? '')
      .split(',')
      .map((g) => g.trim())
      .where((g) => g.isNotEmpty)
      .toList();

  SourceMangaStatus _mapStatus(int status) => switch (status) {
    1 => SourceMangaStatus.ongoing,
    2 || 4 => SourceMangaStatus.completed,
    5 => SourceMangaStatus.cancelled,
    6 => SourceMangaStatus.hiatus,
    _ => SourceMangaStatus.unknown,
  };
}
