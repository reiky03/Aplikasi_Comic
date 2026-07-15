import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';

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
    );
  }
}

/// Data demo mengikuti prototipe.
const _seedSources = [
  ComicSource(id: 's1', name: 'AsuraToons', url: 'asuratoons.example', lang: 'EN', hue: 265),
  ComicSource(id: 's2', name: 'MangaVerse', url: 'mangaverse.example', lang: 'EN', hue: 190),
  ComicSource(id: 's3', name: 'KomikStation', url: 'komikstation.example', lang: 'ID', hue: 130, status: SourceStatus.webview),
  ComicSource(id: 's5', name: 'MangaFox Scans', url: 'mangafox-scans.example', lang: 'EN', hue: 20, status: SourceStatus.limited),
  ComicSource(id: 's6', name: 'ScanVault', url: 'scanvault.example', lang: 'EN', hue: 0, status: SourceStatus.failed),
  ComicSource(id: 's4', name: 'ReaperReads', url: 'reaperreads.example', lang: 'EN', hue: 40, active: false),
];

class SourcesNotifier extends Notifier<List<ComicSource>> {
  @override
  List<ComicSource> build() => _seedSources;

  void add(ComicSource source) => state = [...state, source];

  void remove(String id) => state = state.where((s) => s.id != id).toList();

  void toggleActive(String id) {
    state = [
      for (final s in state)
        if (s.id == id) s.copyWith(active: !s.active) else s,
    ];
  }

  void setSession(String id, bool session) {
    state = [
      for (final s in state)
        if (s.id == id) s.copyWith(session: session) else s,
    ];
  }
}

final sourcesProvider =
    NotifierProvider<SourcesNotifier, List<ComicSource>>(SourcesNotifier.new);
