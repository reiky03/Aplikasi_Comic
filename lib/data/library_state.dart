import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firestore_scope.dart';
import 'models.dart';

/// Data demo — dipakai saat belum login/Firebase tak tersedia (mode
/// `FAKE_AUTH`, web preview, widget test).
const _seedLibrary = [
  Comic(
    id: 'c1',
    title: 'Echoes of the Void',
    src: 'MangaVerse',
    hue: 265,
    ch: 42,
    unread: 3,
    read: 40,
    col: 'reading',
  ),
  Comic(
    id: 'c2',
    title: 'Crimson Vow',
    src: 'AsuraToons',
    hue: 350,
    ch: 108,
    unread: 0,
    read: 108,
    col: 'fav',
  ),
  Comic(
    id: 'c3',
    title: 'Neon Samurai',
    src: 'MangaVerse',
    hue: 190,
    ch: 78,
    unread: 12,
    read: 77,
    col: 'reading',
  ),
  Comic(
    id: 'c4',
    title: 'Garden of Ashes',
    src: 'KomikStation',
    hue: 130,
    ch: 5,
    unread: 1,
    read: 4,
    col: 'later',
  ),
  Comic(
    id: 'c5',
    title: 'The Last Alchemist',
    src: 'ReaperReads',
    hue: 40,
    ch: 210,
    unread: 0,
    read: 210,
    col: 'fav',
  ),
  Comic(
    id: 'c6',
    title: 'Starlight Requiem',
    src: 'AsuraToons',
    hue: 300,
    ch: 23,
    unread: 2,
    read: 21,
    col: 'later',
  ),
];

const _seedCollections = [
  ComicCollection(id: 'reading', name: 'Sedang Dibaca'),
  ComicCollection(id: 'fav', name: 'Favorit'),
  ComicCollection(id: 'later', name: 'Nanti Dibaca'),
];

/// Bentuk judul yang stabil buat mendeteksi komik sama dari source berbeda.
/// Tanda baca dan variasi spasi diabaikan, tetapi huruf non-Latin tetap utuh.
String normalizeLibraryTitle(String title) {
  return title
      .toLowerCase()
      .replaceAll("'", '')
      .replaceAll('\u2019', '')
      .replaceAll('"', '')
      .replaceAll(RegExp(r'[\s\-_/\\:;,.!?()\[\]{}]+'), ' ')
      .trim();
}

bool sameLibraryTitle(String first, String second) {
  final normalizedFirst = normalizeLibraryTitle(first);
  final normalizedSecond = normalizeLibraryTitle(second);
  if (normalizedFirst.isEmpty || normalizedSecond.isEmpty) return false;
  if (normalizedFirst == normalizedSecond) return true;

  // Pakai batas kata agar judul pendek seperti "One" tidak dianggap sama
  // dengan "Someone", tetapi "Solo Leveling" tetap terdeteksi di dalam
  // "Solo Leveling Official".
  final paddedFirst = ' $normalizedFirst ';
  final paddedSecond = ' $normalizedSecond ';
  return paddedFirst.contains(paddedSecond) ||
      paddedSecond.contains(paddedFirst);
}

/// `users/{uid}/library/{comicId}` — lihat docs/DATABASE.md.
/// Firestore tersedia (login asli) → stream langsung dari cloud, mutasi =
/// tulis dokumen (listener yang mengurus update `state`). Tidak tersedia
/// (FAKE_AUTH/test) → data demo in-memory seperti sebelumnya.
class LibraryNotifier extends Notifier<List<Comic>> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  CollectionReference<Map<String, dynamic>>? get _col =>
      FirestoreScope.collection('library');

  @override
  List<Comic> build() {
    ref.onDispose(() => _sub?.cancel());
    final col = _col;
    if (col == null) return _seedLibrary;
    _sub = col.snapshots().listen((snap) {
      state = snap.docs.map((d) => Comic.fromMap(d.id, d.data())).toList();
    });
    return const [];
  }

  Future<void> moveToCollection(String comicId, String? collectionId) async {
    final col = _col;
    if (col == null) {
      state = [
        for (final c in state)
          if (c.id == comicId)
            c.copyWith(col: collectionId, clearCol: collectionId == null)
          else
            c,
      ];
      return;
    }
    await col.doc(comicId).update({
      'collectionId': collectionId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Tambah komik baru ke library (paling depan, seperti prototipe).
  Future<void> add(Comic comic, {String? collectionId}) async {
    final col = _col;
    final withCol = comic.copyWith(col: collectionId);
    if (col == null) {
      state = [withCol, ...state];
      return;
    }
    await col.doc(comic.id).set({
      ...withCol.toMap(),
      'addedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Ganti semua entri beda-source yang judul normalnya sama dengan [comic].
  /// Firestore memakai batch supaya entri lama dan baru tidak sempat muncul
  /// bersamaan saat listener library menerima snapshot.
  Future<void> replaceByTitle(Comic comic, {String? collectionId}) async {
    final duplicateIds = state
        .where(
          (saved) =>
              saved.id != comic.id &&
              sameLibraryTitle(saved.title, comic.title),
        )
        .map((saved) => saved.id)
        .toSet();
    final withCol = comic.copyWith(col: collectionId);
    final col = _col;
    if (col == null) {
      state = [
        withCol,
        ...state.where(
          (saved) => saved.id != comic.id && !duplicateIds.contains(saved.id),
        ),
      ];
      return;
    }

    final batch = FirebaseFirestore.instance.batch();
    for (final id in duplicateIds) {
      batch.delete(col.doc(id));
    }
    batch.set(col.doc(comic.id), {
      ...withCol.toMap(),
      'addedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> markFinished(String comicId) async {
    final col = _col;
    if (col == null) {
      state = [
        for (final c in state)
          if (c.id == comicId) c.copyWith(unread: 0, read: c.ch) else c,
      ];
      return;
    }
    final current = state.where((c) => c.id == comicId).firstOrNull;
    if (current == null) return;
    await col.doc(comicId).update({
      'unread': 0,
      'read': current.ch,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> remove(String comicId) async {
    final col = _col;
    if (col == null) {
      state = state.where((c) => c.id != comicId).toList();
      return;
    }
    await col.doc(comicId).delete();
  }

  /// Lepas semua komik dari koleksi yang dihapus (komik tetap ada).
  Future<void> unassignCollection(String collectionId) async {
    final col = _col;
    if (col == null) {
      state = [
        for (final c in state)
          if (c.col == collectionId) c.copyWith(clearCol: true) else c,
      ];
      return;
    }
    final affected = state.where((c) => c.col == collectionId);
    final batch = FirebaseFirestore.instance.batch();
    for (final c in affected) {
      batch.update(col.doc(c.id), {
        'collectionId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Update progres baca (dipanggil dari Reader, debounced di caller).
  /// Diam-diam tidak melakukan apa pun kalau [comicId] belum tersimpan
  /// di Library (baca tanpa simpan dulu) — progres bacanya tetap
  /// tercatat lewat `history`, cuma tidak ada dokumen `library` untuk
  /// di-update. Cek keberadaan di [state] dulu (bukan langsung `.update()`
  /// Firestore) supaya tidak melempar error "not-found" yang gagal diam-diam.
  Future<void> updateProgress(
    String comicId, {
    required int read,
    int? page,
    int? pages,
    String? chapterUrl,
    String? chapterLabel,
  }) async {
    final current = state.where((c) => c.id == comicId).firstOrNull;
    if (current == null) return;
    final chapterProgress = _chapterProgressFor(
      page: page,
      pages: pages,
      chapterUrl: chapterUrl,
      chapterLabel: chapterLabel,
    );
    final updatedProgress = chapterProgress == null
        ? current.chapterProgress
        : {...current.chapterProgress, read: chapterProgress};
    final col = _col;
    if (col == null) {
      state = [
        for (final c in state)
          if (c.id == comicId)
            c.copyWith(
              read: read,
              unread: read >= c.ch ? 0 : c.unread,
              chapterProgress: updatedProgress,
            )
          else
            c,
      ];
      return;
    }
    await col.doc(comicId).update(<Object, Object?>{
      'read': read,
      if (read >= current.ch) 'unread': 0,
      if (chapterProgress != null)
        FieldPath(['chapterProgress', '$read']): chapterProgress.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  ChapterProgress? _chapterProgressFor({
    int? page,
    int? pages,
    String? chapterUrl,
    String? chapterLabel,
  }) {
    if (page == null || pages == null || page <= 0 || pages <= 0) {
      return null;
    }
    return ChapterProgress(
      page: page.clamp(1, pages).toInt(),
      pages: pages,
      chapterUrl: chapterUrl,
      chapterLabel: chapterLabel,
    );
  }

  /// Tandai satu chapter [chapterNum] *selesai* dibaca (halaman terakhir
  /// tercapai) — beda dari [updateProgress] yang cuma mencatat "sedang di
  /// chapter berapa" (dipanggil tiap ganti halaman/chapter, walau belum
  /// tentu tamat). Idempotent — aman dipanggil berkali-kali.
  Future<void> markChapterRead(String comicId, int chapterNum) async {
    final current = state.where((c) => c.id == comicId).firstOrNull;
    if (current == null) return;
    if (current.readChapters.contains(chapterNum)) return;
    final updated = {...current.readChapters, chapterNum};
    final updatedProgress = {...current.chapterProgress}..remove(chapterNum);
    final col = _col;
    if (col == null) {
      state = [
        for (final c in state)
          if (c.id == comicId)
            c.copyWith(readChapters: updated, chapterProgress: updatedProgress)
          else
            c,
      ];
      return;
    }
    await col.doc(comicId).update({
      'readChapters': (updated.toList()..sort()),
      FieldPath(['chapterProgress', '$chapterNum']): FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Terapkan chapter baru yang ketemu dari pengecekan Updates
  /// (`updates_state.dart`) — update total chapter, tambah badge unread,
  /// dan simpan [lastChapterUrl] (chapter TERBARU yang diketahui) buat
  /// deteksi update berikutnya.
  Future<void> applyNewChapters(
    String comicId, {
    required int newTotal,
    required int deltaUnread,
    String? lastChapterUrl,
  }) async {
    final current = state.where((c) => c.id == comicId).firstOrNull;
    if (current == null) return;
    final col = _col;
    if (col == null) {
      state = [
        for (final c in state)
          if (c.id == comicId)
            c.copyWith(
              ch: newTotal,
              unread: current.unread + deltaUnread,
              lastChapterUrl: lastChapterUrl,
            )
          else
            c,
      ];
      return;
    }
    await col.doc(comicId).update({
      'totalChapters': newTotal,
      'unread': current.unread + deltaUnread,
      'lastChapterUrl': ?lastChapterUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

final libraryProvider = NotifierProvider<LibraryNotifier, List<Comic>>(
  LibraryNotifier.new,
);

class CollectionsNotifier extends Notifier<List<ComicCollection>> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  CollectionReference<Map<String, dynamic>>? get _col =>
      FirestoreScope.collection('collections');

  @override
  List<ComicCollection> build() {
    ref.onDispose(() => _sub?.cancel());
    final col = _col;
    if (col == null) return _seedCollections;
    _sub = col.snapshots().listen((snap) {
      state = snap.docs
          .map((d) => ComicCollection.fromMap(d.id, d.data()))
          .toList();
    });
    return const [];
  }

  /// Buat koleksi baru, kembalikan id-nya.
  Future<String> create(String name) async {
    final id = 'col${DateTime.now().millisecondsSinceEpoch}';
    final col = _col;
    if (col == null) {
      state = [...state, ComicCollection(id: id, name: name)];
      return id;
    }
    await col.doc(id).set({
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  /// Ganti nama koleksi — komik di dalamnya tetap terhubung (relasi lewat
  /// `collectionId`, bukan nama), jadi rename tidak perlu sentuh `library`.
  Future<void> rename(String id, String newName) async {
    final col = _col;
    if (col == null) {
      state = [
        for (final c in state)
          if (c.id == id) ComicCollection(id: id, name: newName) else c,
      ];
      return;
    }
    await col.doc(id).update({'name': newName});
  }

  Future<void> delete(String id) async {
    final col = _col;
    if (col == null) {
      state = state.where((c) => c.id != id).toList();
    } else {
      await col.doc(id).delete();
    }
    await ref.read(libraryProvider.notifier).unassignCollection(id);
  }
}

final collectionsProvider =
    NotifierProvider<CollectionsNotifier, List<ComicCollection>>(
      CollectionsNotifier.new,
    );
