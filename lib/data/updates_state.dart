import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firestore_scope.dart';
import 'library_state.dart';
import 'models.dart';
import 'repository_state.dart';
import 'source_resolver.dart';
import 'source_url.dart';
import 'sources_state.dart';

/// Satu entri chapter baru di feed Updates — satu dokumen per komik
/// (chapter terbaru yang terdeteksi), lihat docs/DATABASE.md.
class UpdateEntry {
  const UpdateEntry({
    required this.comicId,
    required this.title,
    required this.src,
    required this.hue,
    required this.ch,
    required this.detectedAt,
    this.chapterLabel,
    this.chapterUrl,
    this.coverUrl,
  });

  final String comicId;
  final String title;
  final String src;
  final int hue;

  /// Nomor chapter terbaru yang terdeteksi saat pengecekan — POSISI
  /// (`total chapter` saat itu), bukan nomor asli situs. Lihat
  /// [chapterLabel] & catatan yang sama di `HistoryEntry.chapterLabel`.
  final int ch;
  final DateTime detectedAt;

  /// Label chapter ASLI dari situs (mis. "Chapter 43.5 Extra") — dipakai
  /// buat tampilan kalau ada, biar konsisten dengan yang Reader tampilkan.
  final String? chapterLabel;
  final String? chapterUrl;
  final String? coverUrl;

  String get initial => title.isEmpty ? '?' : title[0];
  String get chLabel => chapterLabel ?? 'Chapter $ch';

  /// Label grup tanggal ("Hari ini", "Kemarin", dst) — dihitung saat
  /// render (bukan disimpan), sama seperti [HistoryEntry.time].
  String get dateGroup {
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(detectedAt.year, detectedAt.month, detectedAt.day))
        .inDays;
    if (diff <= 0) return 'Hari ini';
    if (diff == 1) return 'Kemarin';
    if (diff < 7) return '$diff hari lalu';
    if (diff < 30) return '${(diff / 7).floor()} minggu lalu';
    return '${(diff / 30).floor()} bulan lalu';
  }

  /// Label waktu relatif ("1j", "18j").
  String get time {
    final diff = DateTime.now().difference(detectedAt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}j';
    return '${diff.inDays}h';
  }

  Map<String, dynamic> toMap() => {
    'comicId': comicId,
    'title': title,
    'sourceName': src,
    'hue': hue,
    'chapter': ch,
    'chapterLabel': ?chapterLabel,
    'chapterUrl': ?chapterUrl,
    'coverUrl': ?coverUrl,
  };

  factory UpdateEntry.fromMap(String docId, Map<String, dynamic> map) {
    final ts = map['detectedAt'];
    return UpdateEntry(
      comicId: map['comicId'] as String? ?? docId,
      title: map['title'] as String? ?? '',
      src: map['sourceName'] as String? ?? '',
      hue: (map['hue'] as num?)?.toInt() ?? 0,
      ch: (map['chapter'] as num?)?.toInt() ?? 0,
      detectedAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      chapterLabel: map['chapterLabel'] as String?,
      chapterUrl: map['chapterUrl'] as String?,
      coverUrl: map['coverUrl'] as String?,
    );
  }
}

/// Ringkasan hasil [UpdatesNotifier.refresh] — dipakai UI buat kasih tau
/// hasil pengecekan (bukan cuma toast generik "diperbarui").
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.checked,
    required this.updated,
    required this.failed,
  });

  final int checked;
  final int updated;
  final int failed;
}

/// Filter tanggal murni di client. Query Firestore tetap tanpa `orderBy` dan
/// tanpa range filter, jadi dokumen pending `serverTimestamp()` tidak hilang.
List<UpdateEntry> filterUpdatesByDate(
  Iterable<UpdateEntry> entries,
  DateTime? selectedDate,
) {
  if (selectedDate == null) return entries.toList();
  return entries
      .where(
        (entry) =>
            entry.detectedAt.year == selectedDate.year &&
            entry.detectedAt.month == selectedDate.month &&
            entry.detectedAt.day == selectedDate.day,
      )
      .toList();
}

typedef LatestChapterDecision = ({
  bool hasNew,
  bool latestChanged,
  int deltaUnread,
});

@visibleForTesting
LatestChapterDecision decideLatestChapterUpdate({
  required String? knownLatestUrl,
  required int knownTotal,
  required UpdateEntry? currentEntry,
  required int fetchedTotal,
  required String fetchedLatestUrl,
  required String fetchedLatestName,
  required String? coverUrl,
}) {
  final hasNew = knownLatestUrl == null
      ? fetchedTotal > knownTotal
      : !sameChapterIdentity(fetchedLatestUrl, knownLatestUrl);
  return (
    hasNew: hasNew,
    latestChanged:
        currentEntry == null ||
        !sameChapterIdentity(currentEntry.chapterUrl, fetchedLatestUrl) ||
        currentEntry.ch != fetchedTotal ||
        currentEntry.chapterLabel != fetchedLatestName ||
        currentEntry.coverUrl != coverUrl,
    deltaUnread: hasNew
        ? (fetchedTotal - knownTotal).clamp(1, fetchedTotal)
        : 0,
  );
}

/// Data demo — dipakai saat belum login/Firebase tak tersedia.
final _seedUpdates = [
  UpdateEntry(
    comicId: 'c3',
    title: 'Neon Samurai',
    src: 'MangaVerse',
    hue: 190,
    ch: 78,
    detectedAt: DateTime.now().subtract(const Duration(hours: 1)),
  ),
  UpdateEntry(
    comicId: 'c1',
    title: 'Echoes of the Void',
    src: 'MangaVerse',
    hue: 265,
    ch: 42,
    detectedAt: DateTime.now().subtract(const Duration(hours: 4)),
  ),
  UpdateEntry(
    comicId: 'c6',
    title: 'Starlight Requiem',
    src: 'AsuraToons',
    hue: 300,
    ch: 23,
    detectedAt: DateTime.now().subtract(const Duration(hours: 18)),
  ),
  UpdateEntry(
    comicId: 'c4',
    title: 'Garden of Ashes',
    src: 'KomikStation',
    hue: 130,
    ch: 5,
    detectedAt: DateTime.now().subtract(const Duration(hours: 22)),
  ),
];

/// `users/{uid}/updates/{comicId}` — hasil pengecekan chapter baru
/// sungguhan lewat parser sumber (lihat lib/sources/), untuk komik
/// Library yang berasal dari sumber asli (`sourceMangaUrl` non-null).
/// Komik dari sumber tanpa parser native (WebView-only) tidak bisa dicek
/// otomatis — dilewati begitu saja, konsisten dengan prinsip "tanpa
/// bypass otomatis" di seluruh app.
class UpdatesNotifier extends Notifier<List<UpdateEntry>> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  CollectionReference<Map<String, dynamic>>? get _col =>
      FirestoreScope.collection('updates');

  @override
  List<UpdateEntry> build() {
    ref.onDispose(() => _sub?.cancel());
    final col = _col;
    if (col == null) return _seedUpdates;
    // Tanpa `orderBy` di query — sort manual di client, lihat catatan
    // yang sama di history_state.dart (orderBy + serverTimestamp bisa
    // bikin dokumen hilang dari hasil selama tulisan masih pending).
    _sub = col.snapshots().listen((snap) {
      final list =
          snap.docs.map((d) => UpdateEntry.fromMap(d.id, d.data())).toList()
            ..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
      state = list;
    }, onError: (Object e) => debugPrint('updates stream error: $e'));
    return const [];
  }

  /// Cek chapter baru untuk semua komik Library yang berasal dari sumber
  /// asli. Menggunakan pool worker berkemampuan konkuren terbatas (3 worker)
  /// agar proses pengecekan 3x lebih cepat tanpa membanjiri server sumber.
  /// Kegagalan per-komik (situs down, parser meleset) dilewati dan tidak
  /// menggagalkan keseluruhan pengecekan.
  Future<UpdateCheckResult> refresh() async {
    final library = ref.read(libraryProvider);
    final libraryNotifier = ref.read(libraryProvider.notifier);
    final customSources = ref.read(sourcesProvider);
    final repositories = ref.read(repositoriesProvider);
    var checked = 0;
    var updated = 0;
    var failed = 0;

    final targetComics =
        library.where((c) => c.sourceMangaUrl != null).toList();
    if (targetComics.isEmpty) {
      return const UpdateCheckResult(checked: 0, updated: 0, failed: 0);
    }

    var cursor = 0;
    Future<void> worker() async {
      while (true) {
        if (cursor >= targetComics.length) break;
        final comic = targetComics[cursor++];
        final mangaUrl = comic.sourceMangaUrl;
        if (mangaUrl == null) continue;
        final source = resolveMangaSource(
          comic.src,
          customSources,
          repositories,
          sourceMangaUrl: mangaUrl,
          comicId: comic.id,
        );
        if (source == null) continue;
        checked++;
        try {
          final activeMangaUrl = rebaseSourceUrl(mangaUrl, source.baseUrl);
          final chapters = await source
              .fetchChapterList(activeMangaUrl)
              .timeout(const Duration(seconds: 15));
          if (chapters.isEmpty) continue;
          if (activeMangaUrl != mangaUrl) {
            await libraryNotifier.updateSourceMangaUrl(comic.id, activeMangaUrl);
          }
          final newest = chapters.first;
          final currentEntry = state
              .where((entry) => entry.comicId == comic.id)
              .firstOrNull;
          final decision = decideLatestChapterUpdate(
            knownLatestUrl: comic.lastChapterUrl,
            knownTotal: comic.ch,
            currentEntry: currentEntry,
            fetchedTotal: chapters.length,
            fetchedLatestUrl: newest.url,
            fetchedLatestName: newest.name,
            coverUrl: comic.coverUrl,
          );
          if (decision.hasNew) {
            final newTotal = chapters.length;
            await libraryNotifier.applyNewChapters(
              comic.id,
              newTotal: newTotal,
              deltaUnread: decision.deltaUnread,
              lastChapterUrl: newest.url,
            );
            updated++;
          } else if (comic.lastChapterUrl == null) {
            await libraryNotifier.applyNewChapters(
              comic.id,
              newTotal: comic.ch,
              deltaUnread: 0,
              lastChapterUrl: newest.url,
            );
          }
          if (decision.hasNew || decision.latestChanged) {
            await _recordUpdate(
              comic.id,
              comic.title,
              comic.src,
              comic.hue,
              comic.coverUrl,
              chapters.length,
              newest.name,
              newest.url,
            );
          }
        } catch (e) {
          debugPrint('Gagal cek chapter baru untuk ${comic.title}: $e');
          failed++;
        }
      }
    }

    final workerCount = math.min(3, targetComics.length);
    await Future.wait(List.generate(workerCount, (_) => worker()));

    return UpdateCheckResult(
      checked: checked,
      updated: updated,
      failed: failed,
    );
  }

  Future<void> _recordUpdate(
    String comicId,
    String title,
    String src,
    int hue,
    String? coverUrl,
    int newCh,
    String chapterLabel,
    String chapterUrl,
  ) async {
    final col = _col;
    if (col == null) {
      state = [
        UpdateEntry(
          comicId: comicId,
          title: title,
          src: src,
          hue: hue,
          coverUrl: coverUrl,
          ch: newCh,
          detectedAt: DateTime.now(),
          chapterLabel: chapterLabel,
          chapterUrl: chapterUrl,
        ),
        ...state.where((e) => e.comicId != comicId),
      ];
      return;
    }
    await col.doc(comicId).set({
      'comicId': comicId,
      'title': title,
      'sourceName': src,
      'hue': hue,
      'coverUrl': ?coverUrl,
      'chapter': newCh,
      'chapterLabel': chapterLabel,
      'chapterUrl': chapterUrl,
      'detectedAt': FieldValue.serverTimestamp(),
    });
  }
}

final updatesProvider = NotifierProvider<UpdatesNotifier, List<UpdateEntry>>(
  UpdatesNotifier.new,
);
