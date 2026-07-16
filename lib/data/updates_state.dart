import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sources/source_catalog.dart';
import 'firestore_scope.dart';
import 'library_state.dart';

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
  });

  final String comicId;
  final String title;
  final String src;
  final int hue;

  /// Nomor chapter terbaru yang terdeteksi saat pengecekan.
  final int ch;
  final DateTime detectedAt;

  String get initial => title.isEmpty ? '?' : title[0];
  String get chLabel => 'Chapter $ch';

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
  Future<UpdateCheckResult> refresh() async {
    final library = ref.read(libraryProvider);
    final libraryNotifier = ref.read(libraryProvider.notifier);
    var checked = 0;
    var updated = 0;
    var failed = 0;
    for (final comic in library) {
      final mangaUrl = comic.sourceMangaUrl;
      if (mangaUrl == null) continue;
      final source =
          SourceCatalog.sources.where((s) => s.name == comic.src).firstOrNull;
      if (source == null) continue;
      checked++;
      try {
        final chapters = await source.fetchChapterList(mangaUrl);
        final newTotal = chapters.length;
        if (newTotal > comic.ch) {
          final delta = newTotal - comic.ch;
          await libraryNotifier.applyNewChapters(
            comic.id,
            newTotal: newTotal,
            deltaUnread: delta,
          );
          await _recordUpdate(comic.id, comic.title, comic.src, comic.hue, newTotal);
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
      'detectedAt': FieldValue.serverTimestamp(),
    });
  }
}

final updatesProvider =
    NotifierProvider<UpdatesNotifier, List<UpdateEntry>>(UpdatesNotifier.new);
