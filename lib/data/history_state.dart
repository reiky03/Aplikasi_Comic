import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Satu entri riwayat baca.
class HistoryEntry {
  const HistoryEntry({
    required this.title,
    required this.src,
    required this.hue,
    required this.chNum,
    required this.page,
    required this.pages,
    required this.time,
  });

  final String title;
  final String src;
  final int hue;
  final int chNum;

  /// Posisi halaman terakhir dibaca.
  final int page;
  final int pages;

  /// Waktu relatif ("2 jam lalu", "Kemarin, 21:40").
  final String time;

  String get initial => title.isEmpty ? '?' : title[0];
  String get pageLabel => 'Ch. $chNum · Hal $page/$pages';
  double get progress => pages == 0 ? 0 : page / pages;
}

/// Data demo mengikuti prototipe. TODO(backend): riwayat asli dari reader.
const _seedHistory = [
  HistoryEntry(title: 'Neon Samurai', src: 'MangaVerse', hue: 190, chNum: 77, page: 14, pages: 40, time: '2 jam lalu'),
  HistoryEntry(title: 'Echoes of the Void', src: 'MangaVerse', hue: 265, chNum: 40, page: 8, pages: 38, time: 'Kemarin, 21:40'),
  HistoryEntry(title: 'Crimson Vow', src: 'AsuraToons', hue: 350, chNum: 108, page: 22, pages: 22, time: '2 hari lalu'),
  HistoryEntry(title: 'Starlight Requiem', src: 'AsuraToons', hue: 300, chNum: 21, page: 3, pages: 45, time: '1 minggu lalu'),
];

class HistoryNotifier extends Notifier<List<HistoryEntry>> {
  @override
  List<HistoryEntry> build() => _seedHistory;

  void clear() => state = const [];
}

final historyProvider =
    NotifierProvider<HistoryNotifier, List<HistoryEntry>>(HistoryNotifier.new);
