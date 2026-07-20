/// Komik dari sumber eksternal (belum tersimpan ke library).
class SourceManga {
  const SourceManga({
    required this.url,
    required this.title,
    this.thumbnailUrl,
    this.headers = const {},
  });

  /// Path/id relatif di situs sumber (bukan judul) — dipakai untuk fetch detail.
  final String url;
  final String title;
  final String? thumbnailUrl;
  final Map<String, String> headers;
}

class SourceMangaPage {
  const SourceMangaPage({required this.mangas, required this.hasNextPage});

  final List<SourceManga> mangas;
  final bool hasNextPage;
}

enum SourceMangaStatus { ongoing, completed, hiatus, cancelled, unknown }

class SourceMangaDetails {
  const SourceMangaDetails({
    this.description,
    this.author,
    this.artist,
    this.genres = const [],
    this.status = SourceMangaStatus.unknown,
    this.thumbnailUrl,
  });

  final String? description;
  final String? author;
  final String? artist;
  final List<String> genres;
  final SourceMangaStatus status;
  final String? thumbnailUrl;
}

class SourceChapter {
  const SourceChapter({required this.url, required this.name, this.dateUpload});

  final String url;
  final String name;
  final DateTime? dateUpload;
}

class SourcePage {
  const SourcePage({
    required this.index,
    required this.imageUrl,
    this.width,
    this.height,
    this.headers = const {},
  });

  final int index;
  final String imageUrl;
  final int? width;
  final int? height;
  final Map<String, String> headers;
}

/// Dilempar saat fetch/parsing dari sumber gagal (network, HTML/JSON tak
/// sesuai ekspektasi, dll) — pesan sudah aman ditampilkan ke user.
class MangaSourceException implements Exception {
  const MangaSourceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Penanda kalau semua parser native sudah dicoba dan user perlu lanjut lewat
/// browser. URL disimpan supaya WebView bisa langsung membuka halaman yang
/// gagal, bukan cuma mengantar user ke beranda sumber.
class MangaSourceWebViewException extends MangaSourceException {
  const MangaSourceWebViewException({
    required String message,
    required this.url,
    this.cause,
  }) : super(message);

  final String url;
  final Object? cause;
}

/// Kontrak parser sumber komik — satu implementasi per situs (mirip
/// konsep "extension" di Tachiyomi, tapi ditulis native Dart supaya jalan
/// di Android & iOS tanpa perlu menjalankan APK Kotlin pihak lain).
abstract interface class MangaSource {
  /// Nama tampilan sumber, mis. "Shinigami".
  String get name;

  /// Base URL kanonis — dipakai untuk mencocokkan URL yang diketik user di
  /// Add Source (lihat `SourceCatalog.matchByUrl`).
  String get baseUrl;

  Future<SourceMangaPage> fetchPopular(int page);
  Future<SourceMangaPage> fetchLatest(int page);
  Future<SourceMangaPage> fetchSearch(String query, int page);

  Future<SourceMangaDetails> fetchMangaDetails(String mangaUrl);
  Future<List<SourceChapter>> fetchChapterList(String mangaUrl);
  Future<List<SourcePage>> fetchPageList(String chapterUrl);
}
