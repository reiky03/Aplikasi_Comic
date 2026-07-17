import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firestore_scope.dart';
import 'library_state.dart';
import 'source_resolver.dart';
import 'sources_state.dart';

/// Satu entri chapter baru di feed Updates — satu dokumen per komik
/// (chapter terbaru yang terdeteksi), lihat docs/DATABASE.md.
class UpdateEntry {
  const UpdateEntry({
    required this.comicId,
    required this.title,
    required this.src,
    required this.hue,
    required this.ch,
    required this.detectedAt,
    this.chapterLabel,
  });

  final String comicId;
  final String title;
  final String src;
  final int hue;

  /// Nomor chapter terbaru yang terdeteksi saat pengecekan — POSISI
  /// (`total chapter` saat itu), bukan nomor asli situs. Lihat
  /// [chapterLabel] & catatan yang sama di `HistoryEntry.chapterLabel`.
  final int ch;
  final DateTime detectedAt;

  /// Label chapter ASLI dari situs (mis. "Chapter 43.5 Extra") — dipakai
  /// buat tampilan kalau ada, biar konsisten dengan yang Reader tampilkan.
  final String? chapterLabel;

  String get initial => title.isEmpty ? '?' : title[0];
  String get chLabel => chapterLabel ?? 'Chapter $ch';

  /// Label grup tanggal ("Hari ini", "Kemarin", dst) — dihitung saat
  /// render (bukan disimpan), sama seperti [HistoryEntry.time].
  String get dateGroup {
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(detectedAt.year, detectedAt.month, detectedAt.day))
        .inDays;
    if (diff <= 0) return 'Hari ini';
    if (diff == 1) return 'Kemarin';
    if (diff < 7) return '$diff hari lalu';
    if (diff < 30) return '${(diff / 7).floor()} minggu lalu';
    return '${(diff / 30).floor()} bulan lalu';
  }

  /// Label waktu relatif ("1j", "18j").
  String get time {
    final diff = DateTime.now().difference(detectedAt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}j';
    return '${diff.inDays}h';
  }

  Map<String, dynamic> toMap() => {
        'comicId': comicId,
        'title': title,
        'sourceName': src,
        'hue': hue,
        'chapter': ch,
        'chapterLabel': ?chapterLabel,
      };

  factory UpdateEntry.fromMap(String docId, Map<String, dynamic> map) {
    final ts = map['detectedAt'];
    return UpdateEntry(
      comicId: map['comicId'] as String? ?? docId,
      title: map['title'] as String? ?? '',
      src: map['sourceName'] as String? ?? '',
      hue: (map['hue'] as num?)?.toInt() ?? 0,
      ch: (map['chapter'] as num?)?.toInt() ?? 0,
      detectedAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      chapterLabel: map['chapterLabel'] as String?,
    );
  }
}

/// Ringkasan hasil [UpdatesNotifier.refresh] — dipakai UI buat kasih tau
/// hasil pengecekan (bukan cuma toast generik "diperbarui").
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.checked,
    required this.updated,
    required this.failed,
  });

  final int checked;
  final int updated;
  final int failed;
}

/// Data demo — dipakai saat belum login/Firebase tak tersedia.
final _seedUpdates = [
  UpdateEntry(comicId: 'c3', title: 'Neon Samurai', src: 'MangaVerse', hue: 190, ch: 78, detectedAt: DateTime.now().subtract(const Duration(hours: 1))),
  UpdateEntry(comicId: 'c1', title: 'Echoes of the Void', src: 'MangaVerse', hue: 265, ch: 42, detectedAt: DateTime.now().subtract(const Duration(hours: 4))),
  UpdateEntry(comicId: 'c6', title: 'Starlight Requiem', src: 'AsuraToons', hue: 300, ch: 23, detectedAt: DateTime.now().subtract(const Duration(hours: 18))),
  UpdateEntry(comicId: 'c4', title: 'Garden of Ashes', src: 'KomikStation', hue: 130, ch: 5, detectedAt: DateTime.now().subtract(const Duration(hours: 22))),
];

/// `users/{uid}/updates/{comicId}` — hasil pengecekan chapter baru
/// sungguhan lewat parser sumber (lihat lib/sources/), untuk komik
/// Library yang berasal dari sumber asli (`sourceMangaUrl` non-null).
/// Komik dari sumber tanpa parser native (WebView-only) tidak bisa dicek
/// otomatis — dilewati begitu saja, konsisten dengan prinsip "tanpa
/// bypass otomatis" di seluruh app.
class UpdatesNotifier extends Notifier<List<UpdateEntry>> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  CollectionReference<Map<String, dynamic>>? get _col =>
      FirestoreScope.collection('updates');

  @override
  List<UpdateEntry> build() {
    ref.onDispose(() => _sub?.cancel());
    final col = _col;
    if (col == null) return _seedUpdates;
    // Tanpa `orderBy` di query — sort manual di client, lihat catatan
    // yang sama di history_state.dart (orderBy + serverTimestamp bisa
    // bikin dokumen hilang dari hasil selama tulisan masih pending).
    _sub = col.snapshots().listen(
      (snap) {
        final list = snap.docs
            .map((d) => UpdateEntry.fromMap(d.id, d.data()))
            .toList()
          ..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
        state = list;
      },
      onError: (Object e) => debugPrint('updates stream error: $e'),
    );
    return const [];
  }

  /// Cek chapter baru untuk semua komik Library yang berasal dari sumber
  /// asli. Sekuensial (bukan paralel) — sengaja, biar tidak membanjiri
  /// situs sumber dengan banyak request sekaligus. Kegagalan per-komik
  /// (situs down, parser meleset) dilewati, tidak menggagalkan keseluruhan
  /// pengecekan.
  ///
  /// Deteksi "ada chapter baru" TIDAK pakai `chapters.length > comic.ch`
  /// doang — jumlah mentah gampang tidak stabil antar fetch (situs bisa
  /// punya chapter spesial/bonus yang bikin hitungan geser meski tidak
  /// ada penambahan sungguhan, sama akar masalah yang bikin nomor chapter
  /// di History dulu suka meleset). Cek chapter TERBARU (`chapters.first`,
  /// list newest-first) beda dari [Comic.lastChapterUrl] yang terakhir
  /// diketahui — itu sinyal yang jauh lebih akurat, terlepas dari noise
  /// pada hitungan total.
  Future<UpdateCheckResult> refresh() async {
    final library = ref.read(libraryProvider);
    final libraryNotifier = ref.read(libraryProvider.notifier);
    final customSources = ref.read(sourcesProvider);
    var checked = 0;
    var updated = 0;
    var failed = 0;
    for (final comic in library) {
      final mangaUrl = comic.sourceMangaUrl;
      if (mangaUrl == null) continue;
      final source = resolveMangaSource(comic.src, customSources);
      if (source == null) continue;
      checked++;
      try {
        final chapters = await source.fetchChapterList(mangaUrl);
        if (chapters.isEmpty) continue;
        final newest = chapters.first;
        final hasNew = comic.lastChapterUrl == null
            // Komik lama sebelum lastChapterUrl ada — fallback ke
            // perbandingan jumlah sekali ini saja, sampai field-nya
            // ke-isi dari pengecekan ini.
            ? chapters.length > comic.ch
            : newest.url != comic.lastChapterUrl;
        if (hasNew) {
          final newTotal = chapters.length;
          // Jumlah chapter baru yang sebenarnya tetap dihitung dari
          // selisih total (buat badge unread) — clamp minimal 1 supaya
          // tidak pernah 0/negatif kalau hitungannya kebetulan turun
          // (mis. situsnya gabung/hapus chapter lama) padahal jelas ada
          // yang baru (chapter terbaru berbeda).
          final delta = (newTotal - comic.ch).clamp(1, newTotal);
          await libraryNotifier.applyNewChapters(
            comic.id,
            newTotal: newTotal,
            deltaUnread: delta,
            lastChapterUrl: newest.url,
          );
          await _recordUpdate(
            comic.id,
            comic.title,
            comic.src,
            comic.hue,
            newTotal,
            newest.name,
          );
          updated++;
        }
      } catch (e) {
        debugPrint('Gagal cek chapter baru untuk ${comic.title}: $e');
        failed++;
      }
    }
    return UpdateCheckResult(checked: checked, updated: updated, failed: failed);
  }

  Future<void> _recordUpdate(
    String comicId,
    String title,
    String src,
    int hue,
    int newCh,
    String chapterLabel,
  ) async {
    final col = _col;
    if (col == null) {
      state = [
        UpdateEntry(
          comicId: comicId,
          title: title,
          src: src,
          hue: hue,
          ch: newCh,
          detectedAt: DateTime.now(),
          chapterLabel: chapterLabel,
        ),
        ...state.where((e) => e.comicId != comicId),
      ];
      return;
    }
    await col.doc(comicId).set({
      'comicId': comicId,
      'title': title,
      'sourceName': src,
      'hue': hue,
      'chapter': newCh,
      'chapterLabel': chapterLabel,
      'detectedAt': FieldValue.serverTimestamp(),
    });
  }
}

final updatesProvider =
    NotifierProvider<UpdatesNotifier, List<UpdateEntry>>(UpdatesNotifier.new);
