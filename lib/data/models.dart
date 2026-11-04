import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

import 'source_url.dart';

/// Progres parsial per chapter di Library.
///
/// Beda dari `history/{comicId}` yang cuma menyimpan posisi TERAKHIR untuk
/// tombol "Lanjut Baca", ini dipakai Comic Detail supaya beberapa chapter
/// yang belum tamat tetap bisa punya label masing-masing ("Hal 3/16",
/// "Hal 4/16") tanpa saling overwrite.
class ChapterProgress {
  const ChapterProgress({
    required this.page,
    required this.pages,
    this.chapterUrl,
    this.chapterLabel,
  });

  final int page;
  final int pages;
  final String? chapterUrl;
  final String? chapterLabel;

  Map<String, dynamic> toMap() => {
    'page': page,
    'pages': pages,
    'chapterUrl': ?chapterUrl,
    'chapterLabel': ?chapterLabel,
  };

  factory ChapterProgress.fromMap(Map<String, dynamic> map) => ChapterProgress(
    page: (map['page'] as num?)?.toInt() ?? 0,
    pages: (map['pages'] as num?)?.toInt() ?? 0,
    chapterUrl: map['chapterUrl'] as String?,
    chapterLabel: map['chapterLabel'] as String?,
  );
}

/// Bentuk URL chapter yang cukup stabil buat pencocokan data lama/baru.
/// Fragment browser dan slash penutup tidak mengubah identitas chapter.
String? normalizeChapterIdentity(String? url) {
  final trimmed = url?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  var value = trimmed;
  final fragmentAt = value.indexOf('#');
  if (fragmentAt >= 0) value = value.substring(0, fragmentAt);
  while (value.length > 1 && value.endsWith('/')) {
    value = value.substring(0, value.length - 1);
  }
  return value.isEmpty ? null : value;
}

bool sameChapterIdentity(String? first, String? second) {
  final normalizedFirst = normalizeChapterIdentity(first);
  final normalizedSecond = normalizeChapterIdentity(second);
  return normalizedFirst != null &&
      normalizedSecond != null &&
      (normalizedFirst == normalizedSecond ||
          sameSourceResourceIdentity(normalizedFirst, normalizedSecond));
}

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
    this.coverHeaders = const {},
    this.sourceMangaUrl,
    this.readChapters = const {},
    this.readChapterUrls = const {},
    this.chapterProgress = const {},
    this.lastChapterUrl,
    this.addedAt,
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

  /// Header source-specific untuk cover extension (mis. Referer/User-Agent).
  final Map<String, String> coverHeaders;

  /// Identifier manga di parser sumber (`MangaSource.fetchMangaDetails`
  /// dkk) — null berarti komik demo/lokal, bukan dari sumber asli.
  final String? sourceMangaUrl;

  /// Nomor chapter yang sudah ditandai *selesai* dibaca (halaman terakhir
  /// tercapai). Dipakai buat tanda per-chapter di Comic Detail — sengaja
  /// bukan diturunkan dari `num < read` (chapter terjauh yang pernah
  /// dibuka), karena user bisa mulai baca dari chapter mana saja (mis.
  /// chapter terbaru duluan), bukan cuma urut dari chapter 1.
  final Set<int> readChapters;

  /// URL chapter sumber asli yang sudah selesai dibaca. Berbeda dari
  /// [readChapters], URL tetap menunjuk chapter yang sama walau situs
  /// menyisipkan chapter baru dan seluruh nomor sintetis bergeser.
  final Set<String> readChapterUrls;

  /// Progress parsial per chapter yang belum tentu selesai dibaca.
  /// Key biasanya nomor chapter sintetis app. Kalau nomor yang sama sudah
  /// ditempati URL lain setelah daftar bergeser, notifier memakai slot negatif
  /// internal; lookup tampilan selalu mendahulukan [ChapterProgress.chapterUrl].
  final Map<int, ChapterProgress> chapterProgress;

  /// URL chapter TERBARU yang diketahui saat terakhir kali chapter list
  /// di-fetch (buat komik dari sumber asli) — dipakai `UpdatesNotifier`
  /// buat deteksi "ada chapter baru beneran apa nggak". SENGAJA bukan
  /// dibandingkan pakai jumlah total chapter (`ch`) doang: jumlah mentah
  /// itu gampang tidak stabil antar fetch (situs bisa punya chapter
  /// spesial/bonus yang bikin hitungan geser meski tidak ada penambahan
  /// sungguhan) — cek "chapter TERBARU beda dari yang terakhir diketahui"
  /// jauh lebih akurat sebagai sinyal, terlepas dari noise pada hitungan.
  final String? lastChapterUrl;

  /// Waktu komik pertama kali disimpan ke Library. Dipakai buat urutan
  /// "Terakhir ditambahkan" dan tidak berubah saat progres baca diperbarui.
  final DateTime? addedAt;

  /// Cari progres dengan URL dulu. Nomor cuma dipakai untuk komik lokal atau
  /// data lama yang belum sempat menyimpan URL; progress ber-URL lain pada
  /// nomor yang sama tidak boleh dianggap milik chapter ini.
  ChapterProgress? progressForChapter(int chapterNum, {String? chapterUrl}) {
    final identity = normalizeChapterIdentity(chapterUrl);
    if (identity != null) {
      for (final progress in chapterProgress.values) {
        if (sameChapterIdentity(progress.chapterUrl, identity)) {
          return progress;
        }
      }
      final legacy = chapterProgress[chapterNum];
      return normalizeChapterIdentity(legacy?.chapterUrl) == null
          ? legacy
          : null;
    }
    return chapterProgress[chapterNum];
  }

  bool isChapterRead(int chapterNum, {String? chapterUrl}) {
    final identity = normalizeChapterIdentity(chapterUrl);
    if (identity != null &&
        readChapterUrls.any((url) => sameChapterIdentity(url, identity))) {
      return true;
    }
    // `readChapters` dipertahankan sebagai fallback buat data sebelum URL
    // disimpan dan buat komik demo/lokal yang memang tidak punya URL.
    return readChapters.contains(chapterNum);
  }

  String get initial => title.isEmpty ? '?' : title[0];

  /// Caption "Ch. N" di bawah judul (logika prototipe: read || ch).
  String get lastLabel => 'Ch. ${read != 0 ? read : ch}';

  Comic copyWith({
    int? ch,
    int? unread,
    int? read,
    String? col,
    bool clearCol = false,
    Map<String, String>? coverHeaders,
    Set<int>? readChapters,
    Set<String>? readChapterUrls,
    Map<int, ChapterProgress>? chapterProgress,
    String? lastChapterUrl,
    DateTime? addedAt,
    String? sourceMangaUrl,
  }) {
    return Comic(
      id: id,
      title: title,
      src: src,
      hue: hue,
      ch: ch ?? this.ch,
      unread: unread ?? this.unread,
      read: read ?? this.read,
      col: clearCol ? null : (col ?? this.col),
      coverUrl: coverUrl,
      coverHeaders: coverHeaders ?? this.coverHeaders,
      sourceMangaUrl: sourceMangaUrl ?? this.sourceMangaUrl,
      readChapters: readChapters ?? this.readChapters,
      readChapterUrls: readChapterUrls ?? this.readChapterUrls,
      chapterProgress: chapterProgress ?? this.chapterProgress,
      lastChapterUrl: lastChapterUrl ?? this.lastChapterUrl,
      addedAt: addedAt ?? this.addedAt,
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
    'coverHeaders': coverHeaders,
    'sourceMangaUrl': sourceMangaUrl,
    'readChapters': readChapters.toList()..sort(),
    'readChapterUrls': readChapterUrls.toList()..sort(),
    'chapterProgress': {
      for (final e in chapterProgress.entries) '${e.key}': e.value.toMap(),
    },
    'lastChapterUrl': ?lastChapterUrl,
  };

  factory Comic.fromMap(String id, Map<String, dynamic> map) {
    final progressMap = <int, ChapterProgress>{};
    final rawProgress = map['chapterProgress'];
    if (rawProgress is Map) {
      for (final entry in rawProgress.entries) {
        final chapter = int.tryParse('${entry.key}');
        final value = entry.value;
        if (chapter == null || value is! Map) continue;
        progressMap[chapter] = ChapterProgress.fromMap(
          value.cast<String, dynamic>(),
        );
      }
    }
    return Comic(
      id: id,
      title: map['title'] as String? ?? '',
      src: map['sourceName'] as String? ?? '',
      hue: (map['hue'] as num?)?.toInt() ?? 0,
      ch: (map['totalChapters'] as num?)?.toInt() ?? 0,
      unread: (map['unread'] as num?)?.toInt() ?? 0,
      read: (map['read'] as num?)?.toInt() ?? 0,
      col: map['collectionId'] as String?,
      coverUrl: map['coverUrl'] as String?,
      coverHeaders: _stringMap(map['coverHeaders']),
      sourceMangaUrl: map['sourceMangaUrl'] as String?,
      readChapters:
          (map['readChapters'] as List?)
              ?.map((e) => (e as num).toInt())
              .toSet() ??
          const {},
      readChapterUrls:
          (map['readChapterUrls'] as List?)
              ?.whereType<String>()
              .map(normalizeChapterIdentity)
              .whereType<String>()
              .toSet() ??
          const {},
      chapterProgress: progressMap,
      lastChapterUrl: map['lastChapterUrl'] as String?,
      addedAt: _dateTime(map['addedAt']),
    );
  }
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

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) return const {};
  return value.map(
    (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
  )..removeWhere((key, value) => key.isEmpty || value.isEmpty);
}

DateTime? _dateTime(Object? value) {
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  return null;
}
