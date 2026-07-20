import 'manga_source.dart';
import 'mangafire_source.dart';
import 'mangathemesia_source.dart';
import 'natsuid_source.dart';
import 'sveltekit_comic_source.dart';
import 'universal_html_source.dart';

/// Parser otomatis untuk sumber custom yang belum punya parserKind tersimpan.
/// Urutannya sengaja paling spesifik dulu, baru parser HTML umum.
class AdaptiveSource implements MangaSource {
  AdaptiveSource({
    required this.name,
    required this.baseUrl,
    List<MangaSource>? strategies,
  }) : _strategies =
           strategies ??
           [
             if (_isMangaFire(baseUrl))
               MangaFireSource(name: name, baseUrl: baseUrl),
             SvelteKitComicSource(name: name, baseUrl: baseUrl),
             UniversalHtmlSource(
               name: name,
               baseUrl: baseUrl,
               enableBrowserSessionFallback: _isToongod(baseUrl),
             ),
             MangaThemesiaSource(name: name, baseUrl: baseUrl),
             NatsuIdSource(name: name, baseUrl: baseUrl),
           ];

  @override
  final String name;

  @override
  final String baseUrl;

  final List<MangaSource> _strategies;

  static bool _isToongod(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase();
    return host == 'toongod.org' || host?.endsWith('.toongod.org') == true;
  }

  static bool _isMangaFire(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase();
    return host == 'mangafire.to' || host?.endsWith('.mangafire.to') == true;
  }

  @override
  Future<SourceMangaPage> fetchPopular(int page) async {
    return await _first(
          (source) => source.fetchPopular(page),
          (result) => result.mangas.isNotEmpty,
        ) ??
        _throwWebView(baseUrl);
  }

  @override
  Future<SourceMangaPage> fetchLatest(int page) async {
    return await _first(
          (source) => source.fetchLatest(page),
          (result) => result.mangas.isNotEmpty,
        ) ??
        _throwWebView(baseUrl);
  }

  @override
  Future<SourceMangaPage> fetchSearch(String query, int page) async {
    return await _first(
          (source) => source.fetchSearch(query, page),
          (result) => result.mangas.isNotEmpty,
        ) ??
        _throwWebView(baseUrl);
  }

  @override
  Future<SourceMangaDetails> fetchMangaDetails(String mangaUrl) async {
    return await _first(
          (source) => source.fetchMangaDetails(mangaUrl),
          _hasDetails,
        ) ??
        _throwWebView(mangaUrl);
  }

  @override
  Future<List<SourceChapter>> fetchChapterList(String mangaUrl) async {
    return await _first(
          (source) => source.fetchChapterList(mangaUrl),
          (chapters) => chapters.isNotEmpty,
        ) ??
        _throwWebView(mangaUrl);
  }

  @override
  Future<List<SourcePage>> fetchPageList(String chapterUrl) async {
    return await _first(
          (source) => source.fetchPageList(chapterUrl),
          (pages) => pages.isNotEmpty,
        ) ??
        _throwWebView(chapterUrl);
  }

  Future<T?> _first<T>(
    Future<T> Function(MangaSource source) operation,
    bool Function(T result) usable,
  ) async {
    for (final strategy in _strategies) {
      try {
        final result = await operation(strategy);
        if (usable(result)) return result;
      } catch (_) {
        // Struktur/network tidak cocok: lanjut ke metode berikutnya.
      }
    }
    return null;
  }

  bool _hasDetails(SourceMangaDetails details) =>
      details.description != null ||
      details.author != null ||
      details.artist != null ||
      details.genres.isNotEmpty ||
      details.thumbnailUrl != null ||
      details.status != SourceMangaStatus.unknown;

  Never _throwWebView(String url) => throw MangaSourceWebViewException(
    message:
        'Semua metode parser $name sudah dicoba. Buka lewat WebView untuk melanjutkan.',
    url: _absoluteUrl(url),
  );

  String _absoluteUrl(String raw) {
    final value = raw.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return Uri.parse(baseUrl).resolve(value).toString();
  }
}
