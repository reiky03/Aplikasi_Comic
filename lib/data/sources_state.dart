import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../sources/source_catalog.dart';
import 'firestore_scope.dart';
import 'repository_state.dart';
import 'source_url.dart';

/// Status akses sebuah sumber.
enum SourceStatus { normal, webview, limited, failed }

/// Sumber komik yang ditambahkan user via URL.
class ComicSource {
  const ComicSource({
    required this.id,
    required this.name,
    required this.url,
    required this.lang,
    required this.hue,
    this.active = true,
    this.status = SourceStatus.normal,
    this.session = false,
    this.parserKind,
    this.repoPackage,
    this.repoSourceId,
    this.nameAliases = const [],
    this.urlAliases = const [],
  });

  final String id;
  final String name;
  final String url;
  final String lang;
  final int hue;
  final bool active;
  final SourceStatus status;

  /// true bila sesi WebView sudah dibuat untuk sumber ini.
  final bool session;

  /// Kalau sumber ini BUKAN salah satu dari 4 sumber native (lihat
  /// lib/sources/source_catalog.dart), tapi berhasil di-auto-detect cocok
  /// dengan salah satu parser TEMA GENERIK (mis. "mangathemesia",
  /// "natsuid") saat ditambahkan — lihat `SourceCatalog.detectGeneric` &
  /// `add_source_screen.dart`. Null berarti tidak ada parser otomatis sama
  /// sekali (WebView Session Mode saja).
  final String? parserKind;

  /// Identitas stabil extension repo. Ini membuat sumber tetap mengikuti
  /// perubahan base URL/domain pada index repository terbaru.
  final String? repoPackage;
  final String? repoSourceId;

  /// Nama/domain lama dipertahankan saat source diedit. Library lama masih
  /// menyimpan `sourceName` dan URL sebelumnya, jadi alias ini menjadi jembatan
  /// tanpa memaksa user menghapus lalu menambahkan ulang seluruh komik.
  final List<String> nameAliases;
  final List<String> urlAliases;

  String get initial => name.isEmpty ? '?' : name[0];

  /// Bisa dibaca otomatis (grid discover tampil) — logika prototipe.
  bool get readable => active && (status == SourceStatus.normal || session);

  bool matchesName(String value) =>
      name == value || nameAliases.any((alias) => alias == value);

  /// Label + warna status — logika prototipe (statusMeta).
  ({String label, Color color}) get statusMeta {
    if (!active) return (label: 'Nonaktif', color: AppColors.textFaint);
    if (session) return (label: 'Session aktif', color: AppColors.success);
    return switch (status) {
      SourceStatus.webview => (
        label: 'Membutuhkan WebView',
        color: AppColors.warning,
      ),
      SourceStatus.limited => (label: 'Terbatas', color: AppColors.warningAlt),
      SourceStatus.failed => (
        label: 'Gagal diakses',
        color: AppColors.dangerAlt,
      ),
      SourceStatus.normal => (label: 'Normal', color: AppColors.success),
    };
  }

  ComicSource copyWith({
    String? name,
    String? url,
    String? lang,
    int? hue,
    bool? active,
    bool? session,
    SourceStatus? status,
    String? parserKind,
    String? repoPackage,
    String? repoSourceId,
    List<String>? nameAliases,
    List<String>? urlAliases,
  }) {
    return ComicSource(
      id: id,
      name: name ?? this.name,
      url: url ?? this.url,
      lang: lang ?? this.lang,
      hue: hue ?? this.hue,
      active: active ?? this.active,
      status: status ?? this.status,
      session: session ?? this.session,
      parserKind: parserKind ?? this.parserKind,
      repoPackage: repoPackage ?? this.repoPackage,
      repoSourceId: repoSourceId ?? this.repoSourceId,
      nameAliases: nameAliases ?? this.nameAliases,
      urlAliases: urlAliases ?? this.urlAliases,
    );
  }

  /// Mapping ke `users/{uid}/sources/{sourceId}` — lihat docs/DATABASE.md.
  Map<String, dynamic> toMap() => {
    'name': name,
    'url': url,
    'lang': lang,
    'hue': hue,
    'active': active,
    'status': status.name,
    'session': session,
    'parserKind': ?parserKind,
    'repoPackage': ?repoPackage,
    'repoSourceId': ?repoSourceId,
    'nameAliases': nameAliases,
    'urlAliases': urlAliases,
  };

  factory ComicSource.fromMap(
    String id,
    Map<String, dynamic> map,
  ) => ComicSource(
    id: id,
    name: map['name'] as String? ?? '',
    url: map['url'] as String? ?? '',
    lang: map['lang'] as String? ?? '',
    hue: (map['hue'] as num?)?.toInt() ?? 0,
    active: map['active'] as bool? ?? true,
    status: SourceStatus.values.firstWhere(
      (s) => s.name == map['status'],
      orElse: () => SourceStatus.normal,
    ),
    session: map['session'] as bool? ?? false,
    parserKind: map['parserKind'] as String?,
    repoPackage: map['repoPackage'] as String?,
    repoSourceId: map['repoSourceId'] as String?,
    nameAliases:
        (map['nameAliases'] as List?)?.whereType<String>().toList() ?? const [],
    urlAliases:
        (map['urlAliases'] as List?)?.whereType<String>().toList() ?? const [],
  );
}

/// Data demo — dipakai saat belum login/Firebase tak tersedia.
const _seedSources = [
  ComicSource(
    id: 's1',
    name: 'AsuraToons',
    url: 'asuratoons.example',
    lang: 'EN',
    hue: 265,
  ),
  ComicSource(
    id: 's2',
    name: 'MangaVerse',
    url: 'mangaverse.example',
    lang: 'EN',
    hue: 190,
  ),
  ComicSource(
    id: 's3',
    name: 'KomikStation',
    url: 'komikstation.example',
    lang: 'ID',
    hue: 130,
    status: SourceStatus.webview,
  ),
  ComicSource(
    id: 's5',
    name: 'MangaFox Scans',
    url: 'mangafox-scans.example',
    lang: 'EN',
    hue: 20,
    status: SourceStatus.limited,
  ),
  ComicSource(
    id: 's6',
    name: 'ScanVault',
    url: 'scanvault.example',
    lang: 'EN',
    hue: 0,
    status: SourceStatus.failed,
  ),
  ComicSource(
    id: 's4',
    name: 'ReaperReads',
    url: 'reaperreads.example',
    lang: 'EN',
    hue: 40,
    active: false,
  ),
];

class SourcesNotifier extends Notifier<List<ComicSource>> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  CollectionReference<Map<String, dynamic>>? get _col =>
      FirestoreScope.collection('sources');

  @override
  List<ComicSource> build() {
    ref.onDispose(() => _sub?.cancel());
    final col = _col;
    if (col == null) return _seedSources;
    _sub = col.snapshots().listen((snap) {
      state = snap.docs
          .map((d) => ComicSource.fromMap(d.id, d.data()))
          .toList();
    });
    return const [];
  }

  Future<void> add(ComicSource source) async {
    final col = _col;
    if (col == null) {
      state = [...state, source];
      return;
    }
    await col.doc(source.id).set({
      ...source.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> update(ComicSource source) async {
    final col = _col;
    if (col == null) {
      state = [
        for (final s in state)
          if (s.id == source.id) source else s,
      ];
      return;
    }
    await col.doc(source.id).update({
      ...source.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> remove(String id) async {
    final col = _col;
    if (col == null) {
      state = state.where((s) => s.id != id).toList();
      return;
    }
    await col.doc(id).delete();
  }

  Future<void> toggleActive(String id) async {
    final col = _col;
    if (col == null) {
      state = [
        for (final s in state)
          if (s.id == id) s.copyWith(active: !s.active) else s,
      ];
      return;
    }
    final current = state.where((s) => s.id == id).firstOrNull;
    if (current == null) return;
    await col.doc(id).update({
      'active': !current.active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setSession(String id, bool session) async {
    final col = _col;
    if (col == null) {
      state = [
        for (final s in state)
          if (s.id == id) s.copyWith(session: session) else s,
      ];
      return;
    }
    await col.doc(id).update({
      'session': session,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Sinkronkan "Sumber Saya" dengan repositori yang terpasang.
  /// Bila ditemukan kecocokan (nama, URL, alias, atau ID package), perbarui
  /// URL aktif ke mirror repo terbaru, tautkan repoPackage & repoSourceId,
  /// simpan URL/nama lama ke dalam aliases, dan gunakan extension-runtime parser
  /// bila extension APK tersedia, agar tidak ada tabrakan versi atau broken link.
  Future<int> syncWithRepositories(List<ComicRepository> repositories) async {
    if (repositories.isEmpty || state.isEmpty) return 0;
    var syncedCount = 0;
    final updatedList = <ComicSource>[];

    for (final source in state) {
      final match = findRepoSource(
        repositories: repositories,
        rawUrl: source.url,
        packageName: source.repoPackage,
        sourceId: source.repoSourceId,
        name: source.name,
        nameAliases: source.nameAliases,
        urlAliases: source.urlAliases,
      );

      if (match == null) {
        updatedList.add(source);
        continue;
      }

      final repoSource = match.source;
      final repoBaseUrl = repoSource.baseUrl?.trim();
      final hasRepoUrl = repoBaseUrl != null && repoBaseUrl.isNotEmpty;

      // Apakah domain repo berbeda dengan URL source saat ini?
      final isDifferentUrl = hasRepoUrl &&
          normalizeSourceBaseUrl(source.url) !=
              normalizeSourceBaseUrl(repoBaseUrl);

      // Gabungkan URL aliases: pertahankan yang lama, tambahkan alias repo, dan
      // jika URL berubah, simpan URL lama sebagai alias agar komik di library tetap terbaca.
      final newUrlAliases = <String>{
        ...source.urlAliases,
        ...repoSource.baseUrlAliases,
        if (isDifferentUrl) source.url,
      }
          .where(
            (u) =>
                u.trim().isNotEmpty &&
                normalizeSourceBaseUrl(u) !=
                    normalizeSourceBaseUrl(repoBaseUrl ?? source.url),
          )
          .toList();

      // Gabungkan Name aliases
      final newNameAliases = <String>{
        ...source.nameAliases,
        ...repoSource.nameAliases,
        if (source.name.trim().toLowerCase() !=
            repoSource.name.trim().toLowerCase())
          repoSource.name.trim(),
      }
          .where(
            (n) =>
                n.trim().isNotEmpty &&
                n.trim().toLowerCase() != source.name.trim().toLowerCase(),
          )
          .toList();

      final newPackage = repoSource.pkg ?? source.repoPackage;
      final newSourceId = repoSource.id.isNotEmpty
          ? repoSource.id
          : source.repoSourceId;

      final isExistingWebParser = source.parserKind != null &&
          !source.parserKind!.startsWith('extension-runtime:');
      final isBuiltIn = SourceCatalog.matchByName(source.name, source.url) != null ||
          SourceCatalog.matchByUrl(source.url) != null;

      final newParserKind = isExistingWebParser
          ? source.parserKind
          : (isBuiltIn
              ? null
              : (repoSource.pkg != null
                  ? 'extension-runtime:${repoSource.pkg}'
                  : (repoSource.parserKind ?? source.parserKind)));

      final hasChanged = isDifferentUrl ||
          source.repoPackage != newPackage ||
          source.repoSourceId != newSourceId ||
          source.parserKind != newParserKind ||
          newUrlAliases.length != source.urlAliases.length ||
          newNameAliases.length != source.nameAliases.length;

      if (hasChanged) {
        final updatedSource = source.copyWith(
          url: isDifferentUrl ? repoBaseUrl : source.url,
          repoPackage: newPackage,
          repoSourceId: newSourceId,
          parserKind: newParserKind,
          urlAliases: newUrlAliases,
          nameAliases: newNameAliases,
        );
        updatedList.add(updatedSource);
        syncedCount++;
      } else {
        updatedList.add(source);
      }
    }

    if (syncedCount > 0) {
      final col = _col;
      if (col == null) {
        state = updatedList;
      } else {
        state = updatedList;
        for (final s in updatedList) {
          final original = state.firstWhere(
            (o) => o.id == s.id,
            orElse: () => s,
          );
          if (original != s) {
            await col.doc(s.id).update({
              ...s.toMap(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    }
    return syncedCount;
  }
}

final sourcesProvider = NotifierProvider<SourcesNotifier, List<ComicSource>>(
  SourcesNotifier.new,
);
