import '../data/extension_runtime.dart';
import '../data/source_session_store.dart';
import 'alternative_source_methods.dart';
import 'manga_source.dart';
import 'mangafire_source.dart';
import 'sveltekit_comic_source.dart';
import 'universal_html_source.dart';

class ExtensionRuntimeSource implements MangaSource {
  ExtensionRuntimeSource({
    required this.name,
    required this.packageName,
    required this.baseUrl,
    this.lang,
    ExtensionRuntimeBridge? bridge,
    MangaSource? fallback,
    AlternativeSourceMethods? alternatives,
  }) : _bridge = bridge ?? const ExtensionRuntimeBridge(),
       _fallback =
           fallback ??
           _defaultFallback(name: name, baseUrl: baseUrl, lang: lang),
       _alternatives =
           alternatives ??
           AlternativeSourceMethods(name: name, baseUrl: baseUrl);

  @override
  final String name;

  final String packageName;

  @override
  final String baseUrl;

  final String? lang;

  final ExtensionRuntimeBridge _bridge;
  final MangaSource _fallback;
  final AlternativeSourceMethods _alternatives;

  static MangaSource _defaultFallback({
    required String name,
    required String baseUrl,
    String? lang,
  }) {
    final host = Uri.tryParse(baseUrl)?.host.toLowerCase();
    if (host == 'soulscans.asia' || host?.endsWith('.soulscans.asia') == true) {
      return SvelteKitComicSource(name: name, baseUrl: baseUrl);
    }
    if (host == 'mangafire.to' || host?.endsWith('.mangafire.to') == true) {
      return MangaFireSource(name: name, baseUrl: baseUrl, lang: lang);
    }
    return UniversalHtmlSource(
      name: name,
      baseUrl: baseUrl,
      enableBrowserSessionFallback:
          host == 'toongod.org' || host?.endsWith('.toongod.org') == true,
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
      if (mapped.mangas.isNotEmpty) return mapped;
    } catch (_) {
      // Extension missing/incompatible/site changed: use adaptive HTML parser.
    }
    try {
      final result = await _fallback.fetchPopular(page);
      if (result.mangas.isNotEmpty) return result;
    } catch (_) {
      // Parser HTML utama gagal: lanjut ke parser alternatif.
    }
    final result = await _alternatives.fetchPopular(page);
    if (result.mangas.isNotEmpty) return result;
    throw _webViewError(baseUrl);
  }

  /// Beberapa extension mengembalikan section pendek (mis. 4 item homepage)
  /// sebagai hasil valid. Coba parser website hanya saat hasilnya kecil; kalau
  /// parser HTML menemukan katalog lebih besar, pakai hasil yang lebih lengkap
  /// tanpa mengganggu extension yang sudah mengembalikan daftar normal.
  Future<SourceMangaPage?> _largerLatestFallback(
    int page,
    SourceMangaPage current,
  ) async {
    final preferFreshCatalog = _prefersFreshCatalogLatest;
    if (!preferFreshCatalog && current.mangas.length >= 20) return null;
    try {
      final fallback = await _fallback.fetchLatest(page);
      if (fallback.mangas.isNotEmpty &&
          (preferFreshCatalog ||
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
              alternative.mangas.length > current.mangas.length)) {
        return alternative;
      }
    } catch (_) {
      // Pertahankan hasil extension yang sudah valid.
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
        final expanded = await _largerLatestFallback(page, mapped);
        return expanded ?? mapped;
      }
    } catch (_) {
      // Continue to fallback.
    }
    try {
      final result = await _fallback.fetchLatest(page);
      if (result.mangas.isNotEmpty) return result;
    } catch (_) {
      // Lanjut ke parser alternatif.
    }
    final result = await _alternatives.fetchLatest(page);
    if (result.mangas.isNotEmpty) return result;
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
    final result = await _alternatives.fetchSearch(query, page);
    if (result.mangas.isNotEmpty) return result;
    throw _webViewError(baseUrl);
  }

  @override
  Future<SourceMangaDetails> fetchMangaDetails(String mangaUrl) async {
    try {
      final manga = await _bridge.fetchMangaDetailsFromExtension(
        packageName,
        mangaUrl: mangaUrl,
        title: '',
        sourceName: name,
        sourceLang: lang,
        baseUrl: baseUrl,
        sessionHeaders: _sessionHeadersFor(mangaUrl),
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
      final details = await _fallback.fetchMangaDetails(mangaUrl);
      if (_hasDetails(details)) return details;
    } catch (_) {
      // Lanjut ke parser alternatif.
    }
    final details = await _alternatives.fetchMangaDetails(mangaUrl);
    if (_hasDetails(details)) return details;
    throw _webViewError(mangaUrl);
  }

  @override
  Future<List<SourceChapter>> fetchChapterList(String mangaUrl) async {
    try {
      final chapters = await _bridge.fetchChapterListFromExtension(
        packageName,
        mangaUrl: mangaUrl,
        title: '',
        sourceName: name,
        sourceLang: lang,
        baseUrl: baseUrl,
        sessionHeaders: _sessionHeadersFor(mangaUrl),
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
      final chapters = await _fallback.fetchChapterList(mangaUrl);
      if (chapters.isNotEmpty) return chapters;
    } catch (_) {
      // Lanjut ke parser alternatif.
    }
    final chapters = await _alternatives.fetchChapterList(mangaUrl);
    if (chapters.isNotEmpty) return chapters;
    throw _webViewError(mangaUrl);
  }

  @override
  Future<List<SourcePage>> fetchPageList(String chapterUrl) async {
    try {
      final pages = await _bridge.fetchPageListFromExtension(
        packageName,
        chapterUrl: chapterUrl,
        chapterName: '',
        sourceName: name,
        sourceLang: lang,
        baseUrl: baseUrl,
        sessionHeaders: _sessionHeadersFor(chapterUrl),
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
      final pages = await _fallback.fetchPageList(chapterUrl);
      if (pages.isNotEmpty) return pages;
    } catch (_) {
      // Lanjut ke parser alternatif.
    }
    final pages = await _alternatives.fetchPageList(chapterUrl);
    if (pages.isNotEmpty) return pages;
    throw _webViewError(chapterUrl);
  }

  MangaSourceWebViewException _webViewError(
    String url,
  ) => MangaSourceWebViewException(
    message:
        'Semua metode parser $name sudah dicoba. Buka lewat WebView untuk melanjutkan.',
    url: _absUrl(url),
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

  String _absUrl(String url) => Uri.parse(baseUrl).resolve(url).toString();

  Map<String, String> _sessionHeadersFor(String url) => {
    ...SourceSessionStore.headersFor(baseUrl),
    ...SourceSessionStore.headersFor(_absUrl(url)),
  };

  bool _sameSite(String imageUrl) {
    final imageHost = Uri.tryParse(_absUrl(imageUrl))?.host;
    final baseHost = Uri.tryParse(baseUrl)?.host;
    if (imageHost == null || baseHost == null) return false;
    return imageHost == baseHost || imageHost.endsWith('.$baseHost');
  }

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
