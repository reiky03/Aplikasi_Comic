import 'manga_source.dart';
import 'mangathemesia_source.dart';
import 'natsuid_source.dart';

/// Kumpulan parser tambahan yang dicoba SETELAH parser utama gagal.
///
/// Jangan menaruh parser utama di sini lagi. Tujuan class ini cuma menjadi
/// jaring pengaman untuk extension repo yang struktur situsnya ternyata
/// cocok dengan tema WordPress lain. Dengan begitu jalur extension yang sudah
/// berhasil tetap menjadi prioritas dan tidak ikut diubah.
class AlternativeSourceMethods implements MangaSource {
  AlternativeSourceMethods({
    required this.name,
    required this.baseUrl,
    List<MangaSource>? strategies,
  }) : _strategies =
           strategies ??
           [
             MangaThemesiaSource(name: name, baseUrl: baseUrl),
             NatsuIdSource(name: name, baseUrl: baseUrl),
           ];

  @override
  final String name;

  @override
  final String baseUrl;

  final List<MangaSource> _strategies;

  @override
  Future<SourceMangaPage> fetchPopular(int page) async {
    return await _first(
          (source) => source.fetchPopular(page),
          (result) => result.mangas.isNotEmpty,
        ) ??
        const SourceMangaPage(mangas: [], hasNextPage: false);
  }

  @override
  Future<SourceMangaPage> fetchLatest(int page) async {
    return await _first(
          (source) => source.fetchLatest(page),
          (result) => result.mangas.isNotEmpty,
        ) ??
        const SourceMangaPage(mangas: [], hasNextPage: false);
  }

  @override
  Future<SourceMangaPage> fetchSearch(String query, int page) async {
    return await _first(
          (source) => source.fetchSearch(query, page),
          (result) => result.mangas.isNotEmpty,
        ) ??
        const SourceMangaPage(mangas: [], hasNextPage: false);
  }

  @override
  Future<SourceMangaDetails> fetchMangaDetails(String mangaUrl) async {
    return await _first(
          (source) => source.fetchMangaDetails(mangaUrl),
          _hasDetails,
        ) ??
        const SourceMangaDetails();
  }

  @override
  Future<List<SourceChapter>> fetchChapterList(String mangaUrl) async {
    return await _first(
          (source) => source.fetchChapterList(mangaUrl),
          (chapters) => chapters.isNotEmpty,
        ) ??
        const [];
  }

  @override
  Future<List<SourcePage>> fetchPageList(String chapterUrl) async {
    return await _first(
          (source) => source.fetchPageList(chapterUrl),
          (pages) => pages.isNotEmpty,
        ) ??
        const [];
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
        // Situs tidak cocok atau sedang menolak request: coba strategi lain.
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
}
