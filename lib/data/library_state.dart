import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';

/// Data demo mengikuti prototipe (backend belum ada — state in-memory).
/// TODO(backend): ganti dengan penyimpanan lokal + sync saat backend siap.
const _seedLibrary = [
  Comic(id: 'c1', title: 'Echoes of the Void', src: 'MangaVerse', hue: 265, ch: 42, unread: 3, read: 40, col: 'reading'),
  Comic(id: 'c2', title: 'Crimson Vow', src: 'AsuraToons', hue: 350, ch: 108, unread: 0, read: 108, col: 'fav'),
  Comic(id: 'c3', title: 'Neon Samurai', src: 'MangaVerse', hue: 190, ch: 78, unread: 12, read: 77, col: 'reading'),
  Comic(id: 'c4', title: 'Garden of Ashes', src: 'KomikStation', hue: 130, ch: 5, unread: 1, read: 4, col: 'later'),
  Comic(id: 'c5', title: 'The Last Alchemist', src: 'ReaperReads', hue: 40, ch: 210, unread: 0, read: 210, col: 'fav'),
  Comic(id: 'c6', title: 'Starlight Requiem', src: 'AsuraToons', hue: 300, ch: 23, unread: 2, read: 21, col: 'later'),
];

const _seedCollections = [
  ComicCollection(id: 'reading', name: 'Sedang Dibaca'),
  ComicCollection(id: 'fav', name: 'Favorit'),
  ComicCollection(id: 'later', name: 'Nanti Dibaca'),
];

class LibraryNotifier extends Notifier<List<Comic>> {
  @override
  List<Comic> build() => _seedLibrary;

  void moveToCollection(String comicId, String? collectionId) {
    state = [
      for (final c in state)
        if (c.id == comicId)
          c.copyWith(col: collectionId, clearCol: collectionId == null)
        else
          c,
    ];
  }

  /// Tambah komik baru ke library (paling depan, seperti prototipe).
  void add(Comic comic, {String? collectionId}) {
    state = [comic.copyWith(col: collectionId), ...state];
  }

  void markFinished(String comicId) {
    state = [
      for (final c in state)
        if (c.id == comicId) c.copyWith(unread: 0, read: c.ch) else c,
    ];
  }

  void remove(String comicId) {
    state = state.where((c) => c.id != comicId).toList();
  }

  /// Lepas semua komik dari koleksi yang dihapus (komik tetap ada).
  void unassignCollection(String collectionId) {
    state = [
      for (final c in state)
        if (c.col == collectionId) c.copyWith(clearCol: true) else c,
    ];
  }
}

final libraryProvider =
    NotifierProvider<LibraryNotifier, List<Comic>>(LibraryNotifier.new);

class CollectionsNotifier extends Notifier<List<ComicCollection>> {
  @override
  List<ComicCollection> build() => _seedCollections;

  /// Buat koleksi baru, kembalikan id-nya.
  String create(String name) {
    final id = 'col${DateTime.now().millisecondsSinceEpoch}';
    state = [...state, ComicCollection(id: id, name: name)];
    return id;
  }

  void delete(String id) {
    state = state.where((c) => c.id != id).toList();
    ref.read(libraryProvider.notifier).unassignCollection(id);
  }
}

final collectionsProvider =
    NotifierProvider<CollectionsNotifier, List<ComicCollection>>(
        CollectionsNotifier.new);
