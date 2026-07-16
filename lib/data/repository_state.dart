import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firestore_scope.dart';

/// Sumber yang tersedia dari sebuah repository.
class RepoSource {
  const RepoSource({
    required this.id,
    required this.name,
    required this.hue,
    required this.lang,
  });

  final String id;
  final String name;
  final int hue;
  final String lang;

  String get initial => name.isEmpty ? '?' : name[0];

  Map<String, dynamic> toMap() =>
      {'id': id, 'name': name, 'hue': hue, 'lang': lang};

  factory RepoSource.fromMap(Map<String, dynamic> map) => RepoSource(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? '',
        hue: (map['hue'] as num?)?.toInt() ?? 0,
        lang: map['lang'] as String? ?? '',
      );
}

/// Repository = satu link index berisi banyak sumber.
class ComicRepository {
  const ComicRepository({
    required this.id,
    required this.name,
    required this.url,
    required this.sources,
  });

  final String id;
  final String name;
  final String url;
  final List<RepoSource> sources;

  ComicRepository copyWith({String? name, String? url}) => ComicRepository(
        id: id,
        name: name ?? this.name,
        url: url ?? this.url,
        sources: sources,
      );

  /// Mapping ke `users/{uid}/repositories/{repoId}` — `sources` di-embed
  /// (bukan subcollection) sesuai docs/DATABASE.md.
  Map<String, dynamic> toMap() => {
        'name': name,
        'url': url,
        'sources': sources.map((s) => s.toMap()).toList(),
      };

  factory ComicRepository.fromMap(String id, Map<String, dynamic> map) =>
      ComicRepository(
        id: id,
        name: map['name'] as String? ?? '',
        url: map['url'] as String? ?? '',
        sources: (map['sources'] as List<dynamic>? ?? [])
            .map((s) => RepoSource.fromMap(Map<String, dynamic>.from(s as Map)))
            .toList(),
      );
}

/// Data demo — dipakai saat belum login/Firebase tak tersedia.
const _seedRepositories = [
  ComicRepository(
    id: 'rp1',
    name: 'Komunitas Scan ID',
    url: 'repo.komunitasscan.example/index.json',
    sources: [
      RepoSource(id: 'rps1', name: 'NusaScans', hue: 210, lang: 'ID'),
      RepoSource(id: 'rps2', name: 'KomikRaya', hue: 150, lang: 'ID'),
      RepoSource(id: 'rps3', name: 'MangaLintang', hue: 30, lang: 'ID'),
    ],
  ),
  ComicRepository(
    id: 'rp2',
    name: 'Global Scan Hub',
    url: 'globalscanhub.example/repo.json',
    sources: [
      RepoSource(id: 'rps4', name: 'InkVerse', hue: 260, lang: 'EN'),
      RepoSource(id: 'rps5', name: 'Duniakomik', hue: 340, lang: 'EN'),
      RepoSource(id: 'rps6', name: 'ToonForge', hue: 190, lang: 'JP'),
      RepoSource(id: 'rps7', name: 'HanComics', hue: 10, lang: 'KR'),
    ],
  ),
];

class RepositoriesNotifier extends Notifier<List<ComicRepository>> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  CollectionReference<Map<String, dynamic>>? get _col =>
      FirestoreScope.collection('repositories');

  @override
  List<ComicRepository> build() {
    ref.onDispose(() => _sub?.cancel());
    final col = _col;
    if (col == null) return _seedRepositories;
    _sub = col.snapshots().listen((snap) {
      state =
          snap.docs.map((d) => ComicRepository.fromMap(d.id, d.data())).toList();
    });
    return const [];
  }

  Future<void> add(ComicRepository repo) async {
    final col = _col;
    if (col == null) {
      state = [...state, repo];
      return;
    }
    await col.doc(repo.id).set({
      ...repo.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> update(String id, {String? name, String? url}) async {
    final col = _col;
    if (col == null) {
      state = [
        for (final r in state)
          if (r.id == id) r.copyWith(name: name, url: url) else r,
      ];
      return;
    }
    await col.doc(id).update({
      'name': ?name,
      'url': ?url,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> remove(String id) async {
    final col = _col;
    if (col == null) {
      state = state.where((r) => r.id != id).toList();
      return;
    }
    await col.doc(id).delete();
  }
}

final repositoriesProvider =
    NotifierProvider<RepositoriesNotifier, List<ComicRepository>>(
        RepositoriesNotifier.new);

/// `users/{uid}/settings/app` (field `activeLangs`) — bahasa yang
/// diaktifkan untuk pengelompokan repository (default prototipe).
class ActiveLangsNotifier extends Notifier<List<String>> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  static const _seed = ['ID', 'EN'];

  DocumentReference<Map<String, dynamic>>? get _doc =>
      FirestoreScope.collection('settings')?.doc('app');

  @override
  List<String> build() {
    ref.onDispose(() => _sub?.cancel());
    final doc = _doc;
    if (doc == null) return _seed;
    _sub = doc.snapshots().listen((snap) {
      final langs = snap.data()?['activeLangs'] as List<dynamic>?;
      state = langs == null ? _seed : langs.cast<String>();
    });
    return _seed;
  }

  Future<void> toggle(String lang) async {
    final next = state.contains(lang)
        ? state.where((l) => l != lang).toList()
        : [...state, lang];
    final doc = _doc;
    if (doc == null) {
      state = next;
      return;
    }
    await doc.set({'activeLangs': next}, SetOptions(merge: true));
  }
}

final activeLangsProvider =
    NotifierProvider<ActiveLangsNotifier, List<String>>(ActiveLangsNotifier.new);

/// `users/{uid}/settings/app` (field `repoBookmarks`) — id sumber
/// repository yang ditandai (bookmark).
class RepoBookmarksNotifier extends Notifier<List<String>> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  DocumentReference<Map<String, dynamic>>? get _doc =>
      FirestoreScope.collection('settings')?.doc('app');

  @override
  List<String> build() {
    ref.onDispose(() => _sub?.cancel());
    final doc = _doc;
    if (doc == null) return const [];
    _sub = doc.snapshots().listen((snap) {
      final ids = snap.data()?['repoBookmarks'] as List<dynamic>?;
      state = ids == null ? const [] : ids.cast<String>();
    });
    return const [];
  }

  Future<void> toggle(String sourceId) async {
    final next = state.contains(sourceId)
        ? state.where((id) => id != sourceId).toList()
        : [...state, sourceId];
    final doc = _doc;
    if (doc == null) {
      state = next;
      return;
    }
    await doc.set({'repoBookmarks': next}, SetOptions(merge: true));
  }
}

final repoBookmarksProvider =
    NotifierProvider<RepoBookmarksNotifier, List<String>>(
        RepoBookmarksNotifier.new);
