import 'package:flutter/widgets.dart';

/// Komik di library / hasil discover.
class Comic {
  const Comic({
    required this.id,
    required this.title,
    required this.src,
    required this.hue,
    required this.ch,
    this.unread = 0,
    this.read = 0,
    this.col,
    this.coverUrl,
    this.sourceMangaUrl,
  });

  final String id;
  final String title;

  /// Nama sumber asal (mis. "MangaVerse") — untuk komik dari sumber asli
  /// (lihat [sourceMangaUrl]), ini persis `MangaSource.name` sehingga bisa
  /// dicocokkan balik via `SourceCatalog`.
  final String src;

  /// Hue placeholder cover — dipakai kalau [coverUrl] null/gagal dimuat.
  final int hue;

  /// Total chapter.
  final int ch;

  final int unread;
  final int read;

  /// id koleksi; null = tanpa koleksi ("Semua" saja).
  final String? col;

  /// URL cover asli dari sumber (null = pakai gradient+inisial placeholder).
  final String? coverUrl;

  /// Identifier manga di parser sumber (`MangaSource.fetchMangaDetails`
  /// dkk) — null berarti komik demo/lokal, bukan dari sumber asli.
  final String? sourceMangaUrl;

  String get initial => title.isEmpty ? '?' : title[0];

  /// Caption "Ch. N" di bawah judul (logika prototipe: read || ch).
  String get lastLabel => 'Ch. ${read != 0 ? read : ch}';

  Comic copyWith({
    int? unread,
    int? read,
    String? col,
    bool clearCol = false,
  }) {
    return Comic(
      id: id,
      title: title,
      src: src,
      hue: hue,
      ch: ch,
      unread: unread ?? this.unread,
      read: read ?? this.read,
      col: clearCol ? null : (col ?? this.col),
      coverUrl: coverUrl,
      sourceMangaUrl: sourceMangaUrl,
    );
  }

  /// Mapping ke `users/{uid}/library/{comicId}` — lihat docs/DATABASE.md.
  Map<String, dynamic> toMap() => {
        'title': title,
        'sourceName': src,
        'hue': hue,
        'totalChapters': ch,
        'unread': unread,
        'read': read,
        'collectionId': col,
        'coverUrl': coverUrl,
        'sourceMangaUrl': sourceMangaUrl,
      };

  factory Comic.fromMap(String id, Map<String, dynamic> map) => Comic(
        id: id,
        title: map['title'] as String? ?? '',
        src: map['sourceName'] as String? ?? '',
        hue: (map['hue'] as num?)?.toInt() ?? 0,
        ch: (map['totalChapters'] as num?)?.toInt() ?? 0,
        unread: (map['unread'] as num?)?.toInt() ?? 0,
        read: (map['read'] as num?)?.toInt() ?? 0,
        col: map['collectionId'] as String?,
        coverUrl: map['coverUrl'] as String?,
        sourceMangaUrl: map['sourceMangaUrl'] as String?,
      );
}

/// Koleksi (kategori) buatan user di Library.
class ComicCollection {
  const ComicCollection({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, dynamic> toMap() => {'name': name};

  factory ComicCollection.fromMap(String id, Map<String, dynamic> map) =>
      ComicCollection(id: id, name: map['name'] as String? ?? '');
}

/// Gradient placeholder cover dari prototipe:
/// linear-gradient(155deg, hsl(h 46% 26%), hsl((h+28)%360 58% 12%)).
LinearGradient comicCover(int hue) {
  return LinearGradient(
    // CSS 155deg → vektor (sin155, -cos155)
    begin: const Alignment(-0.42, -0.91),
    end: const Alignment(0.42, 0.91),
    colors: [
      HSLColor.fromAHSL(1, hue.toDouble(), 0.46, 0.26).toColor(),
      HSLColor.fromAHSL(1, ((hue + 28) % 360).toDouble(), 0.58, 0.12).toColor(),
    ],
  );
}
