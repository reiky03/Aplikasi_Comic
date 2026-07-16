import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firestore_scope.dart';

/// Satu bookmark — "momen epic" yang ditandai user di halaman tertentu
/// suatu chapter, biar gampang ditemukan lagi lain kali. Beda dari
/// `history` (posisi baca TERAKHIR, satu per komik) — bookmark bisa
/// banyak per komik/chapter, dan tidak berubah/tertimpa oleh progres baca
/// biasa. doc id = `{comicId}_ch{chNum}_p{page}` (deterministik, jadi
/// toggle on/off = set/delete dokumen yang sama, tidak ada duplikat).
class BookmarkEntry {
  const BookmarkEntry({
    required this.id,
    required this.comicId,
    required this.title,
    required this.src,
    required this.hue,
    required this.chNum,
    required this.chapterLabel,
    required this.page,
    required this.pages,
    required this.createdAt,
    this.chapterUrl,
  });

  final String id;
  final String comicId;
  final String title;
  final String src;
  final int hue;
  final int chNum;

  /// Label chapter buat ditampilkan (mis. nama chapter asli, atau
  /// "Chapter N" untuk komik demo).
  final String chapterLabel;
  final int page;
  final int pages;
  final DateTime createdAt;

  /// URL chapter asli — identifier STABIL dipakai buat lompat balik,
  /// beda dari [chNum] yang cuma posisi relatif saat chapter list
  /// di-fetch. Lihat catatan sama di `HistoryEntry.chapterUrl`.
  final String? chapterUrl;

  Map<String, dynamic> toMap() => {
        'comicId': comicId,
        'title': title,
        'sourceName': src,
        'hue': hue,
        'chapter': chNum,
        'chapterLabel': chapterLabel,
        'page': page,
        'pages': pages,
        'chapterUrl': ?chapterUrl,
      };

  factory BookmarkEntry.fromMap(String id, Map<String, dynamic> map) {
    final ts = map['createdAt'];
    return BookmarkEntry(
      id: id,
      comicId: map['comicId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      src: map['sourceName'] as String? ?? '',
      hue: (map['hue'] as num?)?.toInt() ?? 0,
      chNum: (map['chapter'] as num?)?.toInt() ?? 0,
      chapterLabel: map['chapterLabel'] as String? ?? '',
      page: (map['page'] as num?)?.toInt() ?? 0,
      pages: (map['pages'] as num?)?.toInt() ?? 0,
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      chapterUrl: map['chapterUrl'] as String?,
    );
  }
}

class BookmarksNotifier extends Notifier<List<BookmarkEntry>> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  CollectionReference<Map<String, dynamic>>? get _col =>
      FirestoreScope.collection('bookmarks');

  @override
  List<BookmarkEntry> build() {
    ref.onDispose(() => _sub?.cancel());
    final col = _col;
    if (col == null) return const [];
    // Sort di client (bukan `.orderBy` di query) — pelajaran dari bug
    // history: field `createdAt` pakai FieldValue.serverTimestamp(),
    // yang bisa bikin dokumen sempat hilang dari hasil orderBy selagi
    // tulisannya masih pending. Lihat docs/DATABASE.md & PROGRESS.md.
    _sub = col.snapshots().listen(
      (snap) {
        final list = snap.docs
            .map((d) => BookmarkEntry.fromMap(d.id, d.data()))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        state = list;
      },
      onError: (Object e) => debugPrint('bookmarks stream error: $e'),
    );
    return const [];
  }

  static String idFor(String comicId, int chNum, int page) =>
      '${comicId}_ch${chNum}_p$page';

  bool isBookmarked(String comicId, int chNum, int page) =>
      state.any((b) => b.id == idFor(comicId, chNum, page));

  List<BookmarkEntry> forComic(String comicId) =>
      state.where((b) => b.comicId == comicId).toList();

  /// Tambah bookmark kalau belum ada di halaman ini, hapus kalau sudah ada.
  Future<void> toggle({
    required String comicId,
    required String title,
    required String src,
    required int hue,
    required int chNum,
    required String chapterLabel,
    required int page,
    required int pages,
    String? chapterUrl,
  }) async {
    final id = idFor(comicId, chNum, page);
    final exists = state.any((b) => b.id == id);
    final col = _col;
    if (col == null) {
      state = exists
          ? state.where((b) => b.id != id).toList()
          : [
              BookmarkEntry(
                id: id,
                comicId: comicId,
                title: title,
                src: src,
                hue: hue,
                chNum: chNum,
                chapterLabel: chapterLabel,
                page: page,
                pages: pages,
                createdAt: DateTime.now(),
                chapterUrl: chapterUrl,
              ),
              ...state,
            ];
      return;
    }
    if (exists) {
      await col.doc(id).delete();
    } else {
      await col.doc(id).set({
        'comicId': comicId,
        'title': title,
        'sourceName': src,
        'hue': hue,
        'chapter': chNum,
        'chapterLabel': chapterLabel,
        'page': page,
        'pages': pages,
        'chapterUrl': ?chapterUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> remove(String id) async {
    final col = _col;
    if (col == null) {
      state = state.where((b) => b.id != id).toList();
      return;
    }
    await col.doc(id).delete();
  }
}

final bookmarksProvider =
    NotifierProvider<BookmarksNotifier, List<BookmarkEntry>>(
        BookmarksNotifier.new);
