import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../sources/source_catalog.dart';
import 'firestore_scope.dart';
import 'library_state.dart';
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

  bool matchesName(String value) {
    final cleanName = name.trim().toLowerCase();
    final cleanValue = value.trim().toLowerCase();
    if (cleanName == cleanValue) return true;
    if (nameAliases.any((alias) => alias.trim().toLowerCase() == cleanValue)) {
      return true;
    }
    final normName = cleanName.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final normVal = cleanValue.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (normName.isNotEmpty && normName == normVal) return true;
    if (normName.startsWith(normVal) || normVal.startsWith(normName)) {
      if ((normName.length - normVal.length).abs() <= 3) return true;
    }
    return false;
  }

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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ComicSource &&
        other.id == id &&
        other.name == name &&
        normalizeSourceBaseUrl(other.url) == normalizeSourceBaseUrl(url) &&
        other.lang == lang &&
        other.hue == hue &&
        other.active == active &&
        other.status == status &&
        other.session == session &&
        other.parserKind == parserKind &&
        other.repoPackage == repoPackage &&
        other.repoSourceId == repoSourceId &&
        setEquals(other.nameAliases.toSet(), nameAliases.toSet()) &&
        setEquals(
          other.urlAliases.map(normalizeSourceBaseUrl).toSet(),
          urlAliases.map(normalizeSourceBaseUrl).toSet(),
        );
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        normalizeSourceBaseUrl(url),
        lang,
        hue,
        active,
        status,
        session,
        parserKind,
        repoPackage,
        repoSourceId,
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
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

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

  /// Perbarui URL sumber (misalnya ketika situs melakukan migrasi/redirect domain).
  /// Membawa URL lama ke dalam `urlAliases` sehingga komik-komik lama di Library
  /// tetap dapat dibuka dan dicocokkan, serta memigrasikan URL komik yang tersimpan.
  Future<bool> updateSourceUrl(String id, String newUrl) async {
    final current = state.where((s) => s.id == id).firstOrNull;
    if (current == null) return false;
    final normalizedNew = normalizeSourceBaseUrl(newUrl);
    final normalizedOld = normalizeSourceBaseUrl(current.url);
    if (normalizedNew.isEmpty || normalizedNew == normalizedOld) return false;

    final updatedAliases = <String>{
      ...current.urlAliases,
      current.url,
      if (normalizedOld.isNotEmpty) normalizedOld,
    }
        .where(
          (u) =>
              u.trim().isNotEmpty &&
              normalizeSourceBaseUrl(u) != normalizedNew,
        )
        .toList();

    final updated = current.copyWith(
      url: normalizedNew,
      urlAliases: updatedAliases,
    );
    await update(updated);

    try {
      final affected = await ref
          .read(libraryProvider.notifier)
          .migrateComicsForDomainChange(
            sourceName: current.name,
            oldUrl: current.url,
            newUrl: normalizedNew,
            oldUrlAliases: updatedAliases,
          );
      ref.read(domainChangesProvider.notifier).notifyChanges([
        DomainChange(
          sourceId: current.id,
          sourceName: current.name,
          oldUrl: current.url,
          newUrl: normalizedNew,
          affectedComicsCount: affected,
          timestamp: DateTime.now(),
        ),
      ]);
    } catch (_) {}

    return true;
  }

  /// Sinkronkan "Sumber Saya" dengan repositori yang terpasang.
  /// Bila ditemukan kecocokan (nama, URL, alias, atau ID package), perbarui
  /// URL aktif ke mirror repo terbaru, tautkan repoPackage & repoSourceId,
  /// simpan URL/nama lama ke dalam aliases, dan gunakan extension-runtime parser
  /// bila extension APK tersedia, agar tidak ada tabrakan versi atau broken link.
  Future<int> syncWithRepositories(List<ComicRepository> repositories) async {
    if (_isSyncing || repositories.isEmpty || state.isEmpty) return 0;
    final now = DateTime.now();
    if (_lastSyncTime != null &&
        now.difference(_lastSyncTime!).inMilliseconds < 3000) {
      return 0;
    }
    _isSyncing = true;
    try {
      var syncedCount = 0;
      final updatedList = <ComicSource>[];
      final domainChanges = <DomainChange>[];

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

        if (isDifferentUrl) {
          domainChanges.add(
            DomainChange(
              sourceId: source.id,
              sourceName: source.name,
              oldUrl: source.url,
              newUrl: repoBaseUrl,
              affectedComicsCount: 0,
              timestamp: DateTime.now(),
            ),
          );
        }
      } else {
        updatedList.add(source);
      }
    }

    if (syncedCount > 0) {
      final previousState = List<ComicSource>.of(state);
      state = updatedList;
      final col = _col;
      if (col != null) {
        for (final s in updatedList) {
          final original = previousState.where((o) => o.id == s.id).firstOrNull;
          if (original == null || original != s) {
            await col.doc(s.id).update({
              ...s.toMap(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      // Migrasikan seluruh komik di Library yang terpengaruh pergantian domain
      if (domainChanges.isNotEmpty) {
        try {
          final libraryNotifier = ref.read(libraryProvider.notifier);
          final finalChanges = <DomainChange>[];
          for (final change in domainChanges) {
            final source = updatedList.firstWhere((s) => s.id == change.sourceId);
            final affected = await libraryNotifier.migrateComicsForDomainChange(
              sourceName: change.sourceName,
              oldUrl: change.oldUrl,
              newUrl: change.newUrl,
              oldUrlAliases: source.urlAliases,
            );
            finalChanges.add(
              DomainChange(
                sourceId: change.sourceId,
                sourceName: change.sourceName,
                oldUrl: change.oldUrl,
                newUrl: change.newUrl,
                affectedComicsCount: affected,
                timestamp: change.timestamp,
              ),
            );
          }
          ref.read(domainChangesProvider.notifier).notifyChanges(finalChanges);
        } catch (_) {}
      }
    }
    return syncedCount;
    } finally {
      _lastSyncTime = DateTime.now();
      _isSyncing = false;
    }
  }
}

/// Riwayat/notifikasi perubahan domain sumber komik.
class DomainChange {
  final String sourceId;
  final String sourceName;
  final String oldUrl;
  final String newUrl;
  final int affectedComicsCount;
  final DateTime timestamp;

  const DomainChange({
    required this.sourceId,
    required this.sourceName,
    required this.oldUrl,
    required this.newUrl,
    required this.affectedComicsCount,
    required this.timestamp,
  });
}

class DomainChangesNotifier extends Notifier<List<DomainChange>> {
  @override
  List<DomainChange> build() => const [];

  void notifyChanges(List<DomainChange> changes) {
    if (changes.isEmpty) return;
    state = [...state, ...changes];
  }

  void clear() {
    state = const [];
  }
}

final domainChangesProvider =
    NotifierProvider<DomainChangesNotifier, List<DomainChange>>(
  DomainChangesNotifier.new,
);

final sourcesProvider = NotifierProvider<SourcesNotifier, List<ComicSource>>(
  SourcesNotifier.new,
);
