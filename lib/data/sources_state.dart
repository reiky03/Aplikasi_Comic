import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import 'firestore_scope.dart';

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

  String get initial => name.isEmpty ? '?' : name[0];

  /// Bisa dibaca otomatis (grid discover tampil) — logika prototipe.
  bool get readable => active && (status == SourceStatus.normal || session);

  /// Label + warna status — logika prototipe (statusMeta).
  ({String label, Color color}) get statusMeta {
    if (!active) return (label: 'Nonaktif', color: AppColors.textFaint);
    if (session) return (label: 'Session aktif', color: AppColors.success);
    return switch (status) {
      SourceStatus.webview => (
          label: 'Membutuhkan WebView',
          color: AppColors.warning
        ),
      SourceStatus.limited => (label: 'Terbatas', color: AppColors.warningAlt),
      SourceStatus.failed => (
          label: 'Gagal diakses',
          color: AppColors.dangerAlt
        ),
      SourceStatus.normal => (label: 'Normal', color: AppColors.success),
    };
  }

  ComicSource copyWith({bool? active, bool? session, SourceStatus? status}) {
    return ComicSource(
      id: id,
      name: name,
      url: url,
      lang: lang,
      hue: hue,
      active: active ?? this.active,
      status: status ?? this.status,
      session: session ?? this.session,
      parserKind: parserKind,
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
      };

  factory ComicSource.fromMap(String id, Map<String, dynamic> map) =>
      ComicSource(
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
      );
}

/// Data demo — dipakai saat belum login/Firebase tak tersedia.
const _seedSources = [
  ComicSource(id: 's1', name: 'AsuraToons', url: 'asuratoons.example', lang: 'EN', hue: 265),
  ComicSource(id: 's2', name: 'MangaVerse', url: 'mangaverse.example', lang: 'EN', hue: 190),
  ComicSource(id: 's3', name: 'KomikStation', url: 'komikstation.example', lang: 'ID', hue: 130, status: SourceStatus.webview),
  ComicSource(id: 's5', name: 'MangaFox Scans', url: 'mangafox-scans.example', lang: 'EN', hue: 20, status: SourceStatus.limited),
  ComicSource(id: 's6', name: 'ScanVault', url: 'scanvault.example', lang: 'EN', hue: 0, status: SourceStatus.failed),
  ComicSource(id: 's4', name: 'ReaperReads', url: 'reaperreads.example', lang: 'EN', hue: 40, active: false),
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
      state = snap.docs.map((d) => ComicSource.fromMap(d.id, d.data())).toList();
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
}

final sourcesProvider =
    NotifierProvider<SourcesNotifier, List<ComicSource>>(SourcesNotifier.new);
