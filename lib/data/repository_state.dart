import 'package:flutter_riverpod/flutter_riverpod.dart';

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
}

/// Data demo mengikuti prototipe.
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
  @override
  List<ComicRepository> build() => _seedRepositories;

  void add(ComicRepository repo) => state = [...state, repo];

  void update(String id, {String? name, String? url}) {
    state = [
      for (final r in state)
        if (r.id == id) r.copyWith(name: name, url: url) else r,
    ];
  }

  void remove(String id) => state = state.where((r) => r.id != id).toList();
}

final repositoriesProvider =
    NotifierProvider<RepositoriesNotifier, List<ComicRepository>>(
        RepositoriesNotifier.new);

/// Bahasa yang diaktifkan untuk pengelompokan repository (default prototipe).
class ActiveLangsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => const ['ID', 'EN'];

  void toggle(String lang) {
    state = state.contains(lang)
        ? state.where((l) => l != lang).toList()
        : [...state, lang];
  }
}

final activeLangsProvider =
    NotifierProvider<ActiveLangsNotifier, List<String>>(ActiveLangsNotifier.new);

/// Id sumber repository yang ditandai (bookmark).
class RepoBookmarksNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void toggle(String sourceId) {
    state = state.contains(sourceId)
        ? state.where((id) => id != sourceId).toList()
        : [...state, sourceId];
  }
}

final repoBookmarksProvider =
    NotifierProvider<RepoBookmarksNotifier, List<String>>(
        RepoBookmarksNotifier.new);
