import '../data/extension_runtime.dart';
import '../data/source_session_store.dart';
import 'manga_source.dart';
import 'universal_html_source.dart';

class ExtensionRuntimeSource implements MangaSource {
  ExtensionRuntimeSource({
    required this.name,
    required this.packageName,
    required this.baseUrl,
    this.lang,
    ExtensionRuntimeBridge? bridge,
    MangaSource? fallback,
  }) : _bridge = bridge ?? const ExtensionRuntimeBridge(),
       _fallback =
           fallback ?? UniversalHtmlSource(name: name, baseUrl: baseUrl);

  @override
  final String name;

  final String packageName;

  @override
  final String baseUrl;

  final String? lang;

  final ExtensionRuntimeBridge _bridge;
  final MangaSource _fallback;

  @override
  Future<SourceMangaPage> fetchPopular(int page) async {
    try {
      final result = await _bridge.fetchPopularFromExtension(
        packageName,
        page: page,
        sourceName: name,
        sourceLang: lang,
        baseUrl: baseUrl,
      );
      final mapped = _toPage(result);
      if (mapped.mangas.isNotEmpty) return mapped;
    } catch (_) {
      // Extension missing/incompatible/site changed: use adaptive HTML parser.
    }
    return _fallback.fetchPopular(page);
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
      );
      final mapped = _toPage(result);
      if (mapped.mangas.isNotEmpty) return mapped;
    } catch (_) {
      // Continue to fallback.
    }
    return _fallback.fetchLatest(page);
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
      );
      final mapped = _toPage(result);
      if (mapped.mangas.isNotEmpty) return mapped;
    } catch (_) {
      // Continue to fallback.
    }
    return _fallback.fetchSearch(query, page);
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
    return _fallback.fetchMangaDetails(mangaUrl);
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
    return _fallback.fetchChapterList(mangaUrl);
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
    return _fallback.fetchPageList(chapterUrl);
  }

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

  bool _sameSite(String imageUrl) {
    final imageHost = Uri.tryParse(imageUrl)?.host;
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
