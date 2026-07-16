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
  });

  final String comicId;
  final String title;
  final String src;
  final int hue;
  final int chNum;

  /// Posisi halaman terakhir dibaca.
  final int page;
  final int pages;

  final DateTime readAt;

  String get initial => title.isEmpty ? '?' : title[0];
  String get pageLabel => 'Ch. $chNum · Hal $page/$pages';
  double get progress => pages == 0 ? 0 : page / pages;

  /// Label waktu relatif ("2 jam lalu", "Kemarin, 21:40") — dihitung saat
  /// render (bukan disimpan), sesuai docs/DATABASE.md.
  String get time => _relativeLabel(readAt);

  Map<String, dynamic> toMap() => {
        'title': title,
        'sourceName': src,
        'hue': hue,
        'chapter': chNum,
        'page': page,
        'pages': pages,
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
  HistoryEntry(comicId: 'c3', title: 'Neon Samurai', src: 'MangaVerse', hue: 190, chNum: 77, page: 14, pages: 40, readAt: DateTime.now().subtract(const Duration(hours: 2))),
  HistoryEntry(comicId: 'c1', title: 'Echoes of the Void', src: 'MangaVerse', hue: 265, chNum: 40, page: 8, pages: 38, readAt: DateTime.now().subtract(const Duration(hours: 27))),
  HistoryEntry(comicId: 'c2', title: 'Crimson Vow', src: 'AsuraToons', hue: 350, chNum: 108, page: 22, pages: 22, readAt: DateTime.now().subtract(const Duration(days: 2))),
  HistoryEntry(comicId: 'c6', title: 'Starlight Requiem', src: 'AsuraToons', hue: 300, chNum: 21, page: 3, pages: 45, readAt: DateTime.now().subtract(const Duration(days: 7))),
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
    _sub = col.snapshots().listen(
      (snap) {
        final list = snap.docs
            .map((d) => HistoryEntry.fromMap(d.id, d.data()))
            .toList()
          ..sort((a, b) => b.readAt.compareTo(a.readAt));
        state = list;
      },
      onError: (Object e) => debugPrint('history stream error: $e'),
    );
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
    );
    final col = _col;
    if (col == null) {
      state = [
        entry,
        ...state.where((h) => h.comicId != comicId),
      ];
      return;
    }
    await col.doc(comicId).set({
      ...entry.toMap(),
      'readAt': FieldValue.serverTimestamp(),
    });
  }
}

final historyProvider =
    NotifierProvider<HistoryNotifier, List<HistoryEntry>>(HistoryNotifier.new);
