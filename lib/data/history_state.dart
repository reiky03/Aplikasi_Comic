import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firestore_scope.dart';

/// Satu entri riwayat baca — satu dokumen per komik (posisi terakhir),
/// doc id = `comicId`. Lihat docs/DATABASE.md.
class HistoryEntry {
  const HistoryEntry({
    required this.comicId,
    required this.title,
    required this.src,
    required this.hue,
    required this.chNum,
    required this.page,
    required this.pages,
    required this.readAt,
    this.chapterUrl,
    this.chapterLabel,
    this.coverUrl,
  });

  final String comicId;
  final String title;
  final String src;
  final int hue;

  /// Posisi ("chapter ke-N dari total chapter SAAT di-fetch") — bukan
  /// nomor asli dari situs, cuma dipakai buat fallback/badge lama. Lihat
  /// [chapterLabel] untuk yang ditampilkan ke user.
  final int chNum;

  /// Posisi halaman terakhir dibaca.
  final int page;
  final int pages;

  final DateTime readAt;

  /// URL chapter asli — identifier STABIL, beda dari [chNum] yang cuma
  /// posisi relatif ("chapter ke-N dari total saat itu di-fetch"). Kalau
  /// daftar chapter situsnya berubah panjang (chapter baru terbit) antara
  /// saat disimpan dan saat "Lanjut Baca" ditekan lagi, [chNum] saja bisa
  /// nunjuk ke chapter yang SALAH — Reader pakai ini dulu (fallback ke
  /// [chNum] kalau null, mis. entri lama sebelum field ini ada).
  final String? chapterUrl;

  /// Label chapter ASLI dari situs (mis. "Chapter 43.5 Extra"), sama
  /// seperti yang ditampilkan Reader — beda dari [chNum] yang cuma
  /// POSISI hasil hitungan kita sendiri (`total - index`), bisa meleset
  /// dari nomor asli situs kalau ada chapter spesial/bonus/non-sekuensial
  /// di daftarnya. Tanpa ini, History bisa nunjukin "Ch. 4" sementara
  /// Reader yang benar-benar dibuka (via [chapterUrl], sudah tepat)
  /// nampilin "Chapter 3" — bukan salah buka chapter, cuma dua sistem
  /// penomoran beda yang gak sinkron tampilannya. Null untuk entri lama.
  final String? chapterLabel;
  final String? coverUrl;

  String get initial => title.isEmpty ? '?' : title[0];
  String get pageLabel => '${chapterLabel ?? 'Ch. $chNum'} · Hal $page/$pages';
  double get progress => pages == 0 ? 0 : page / pages;

  /// Label waktu relatif ("2 jam lalu", "Kemarin, 21:40") — dihitung saat
  /// render (bukan disimpan), sesuai docs/DATABASE.md.
  String get time => _relativeLabel(readAt);

  /// Label grup tanggal ("Hari ini", "Kemarin", "2 hari lalu", dst) —
  /// dipakai buat header pemisah di layar History, sama persis dengan
  /// [UpdateEntry.dateGroup] biar dua tab konsisten. Dihitung dari
  /// perbedaan HARI kalender (bukan selisih jam mentah) supaya jam 23:00
  /// vs 01:00 keesokan harinya tetap kebaca beda hari, bukan "sama-sama <24
  /// jam".
  String get dateGroup {
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(readAt.year, readAt.month, readAt.day))
        .inDays;
    if (diff <= 0) return 'Hari ini';
    if (diff == 1) return 'Kemarin';
    if (diff < 7) return '$diff hari lalu';
    if (diff < 30) return '${(diff / 7).floor()} minggu lalu';
    return '${(diff / 30).floor()} bulan lalu';
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'sourceName': src,
    'hue': hue,
    'chapter': chNum,
    'page': page,
    'pages': pages,
    'chapterUrl': ?chapterUrl,
    'chapterLabel': ?chapterLabel,
    'coverUrl': ?coverUrl,
  };

  factory HistoryEntry.fromMap(String comicId, Map<String, dynamic> map) {
    final ts = map['readAt'];
    return HistoryEntry(
      comicId: comicId,
      title: map['title'] as String? ?? '',
      src: map['sourceName'] as String? ?? '',
      hue: (map['hue'] as num?)?.toInt() ?? 0,
      chNum: (map['chapter'] as num?)?.toInt() ?? 0,
      page: (map['page'] as num?)?.toInt() ?? 0,
      pages: (map['pages'] as num?)?.toInt() ?? 0,
      readAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      chapterLabel: map['chapterLabel'] as String?,
      chapterUrl: map['chapterUrl'] as String?,
      coverUrl: map['coverUrl'] as String?,
    );
  }
}

String _twoDigits(int n) => n.toString().padLeft(2, '0');

String _relativeLabel(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inHours < 48) {
    return 'Kemarin, ${_twoDigits(dt.hour)}:${_twoDigits(dt.minute)}';
  }
  if (diff.inDays < 7) return '${diff.inDays} hari lalu';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} minggu lalu';
  return '${(diff.inDays / 30).floor()} bulan lalu';
}

/// Data demo — dipakai saat belum login/Firebase tak tersedia.
final _seedHistory = [
  HistoryEntry(
    comicId: 'c3',
    title: 'Neon Samurai',
    src: 'MangaVerse',
    hue: 190,
    chNum: 77,
    page: 14,
    pages: 40,
    readAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  HistoryEntry(
    comicId: 'c1',
    title: 'Echoes of the Void',
    src: 'MangaVerse',
    hue: 265,
    chNum: 40,
    page: 8,
    pages: 38,
    readAt: DateTime.now().subtract(const Duration(hours: 27)),
  ),
  HistoryEntry(
    comicId: 'c2',
    title: 'Crimson Vow',
    src: 'AsuraToons',
    hue: 350,
    chNum: 108,
    page: 22,
    pages: 22,
    readAt: DateTime.now().subtract(const Duration(days: 2)),
  ),
  HistoryEntry(
    comicId: 'c6',
    title: 'Starlight Requiem',
    src: 'AsuraToons',
    hue: 300,
    chNum: 21,
    page: 3,
    pages: 45,
    readAt: DateTime.now().subtract(const Duration(days: 7)),
  ),
];

class HistoryNotifier extends Notifier<List<HistoryEntry>> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  CollectionReference<Map<String, dynamic>>? get _col =>
      FirestoreScope.collection('history');

  @override
  List<HistoryEntry> build() {
    ref.onDispose(() => _sub?.cancel());
    final col = _col;
    if (col == null) return _seedHistory;
    // Sort di client (bukan `.orderBy('readAt')` di query) — field ini
    // ditulis pakai FieldValue.serverTimestamp(), yang nilainya `null` di
    // cache lokal selama tulisan masih pending. Firestore mengecualikan
    // dokumen dari hasil orderBy kalau field urutnya null/belum ke-resolve,
    // jadi entri baru sempat hilang total dari listener sampai ack server
    // datang — makanya riwayat kelihatan "tidak pernah ke-track".
    _sub = col.snapshots().listen((snap) {
      final list =
          snap.docs.map((d) => HistoryEntry.fromMap(d.id, d.data())).toList()
            ..sort((a, b) => b.readAt.compareTo(a.readAt));
      state = list;
    }, onError: (Object e) => debugPrint('history stream error: $e'));
    return const [];
  }

  Future<void> clear() async {
    final col = _col;
    if (col == null) {
      state = const [];
      return;
    }
    final snap = await col.get();
    final batch = FirebaseFirestore.instance.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  /// Update/buat posisi baca terakhir (dipanggil dari Reader, debounced).
  Future<void> upsert({
    required String comicId,
    required String title,
    required String src,
    required int hue,
    required int chNum,
    required int page,
    required int pages,
    String? chapterUrl,
    String? chapterLabel,
    String? coverUrl,
  }) async {
    final entry = HistoryEntry(
      comicId: comicId,
      title: title,
      src: src,
      hue: hue,
      chNum: chNum,
      page: page,
      pages: pages,
      readAt: DateTime.now(),
      chapterUrl: chapterUrl,
      chapterLabel: chapterLabel,
      coverUrl: coverUrl,
    );
    final col = _col;
    if (col == null) {
      state = [entry, ...state.where((h) => h.comicId != comicId)];
      return;
    }
    await col.doc(comicId).set({
      ...entry.toMap(),
      'readAt': FieldValue.serverTimestamp(),
    });
  }
}

final historyProvider = NotifierProvider<HistoryNotifier, List<HistoryEntry>>(
  HistoryNotifier.new,
);
