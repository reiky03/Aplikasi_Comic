import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';

/// Satu entri chapter baru di feed Updates.
class UpdateEntry {
  const UpdateEntry({
    required this.dateGroup,
    required this.title,
    required this.src,
    required this.hue,
    required this.ch,
    required this.time,
  });

  /// Label grup tanggal ("Hari ini", "Kemarin") — dirender uppercase.
  final String dateGroup;
  final String title;
  final String src;
  final int hue;
  final int ch;

  /// Waktu relatif ("1j", "18j").
  final String time;

  String get initial => title.isEmpty ? '?' : title[0];
  String get chLabel => 'Chapter $ch';

  /// Komik target saat row di-tap (logika prototipe: read = ch - 1
  /// supaya user bisa langsung lompat ke chapter baru).
  Comic toComic() => Comic(
        id: 'u',
        title: title,
        src: src,
        hue: hue,
        ch: ch,
        read: ch - 1,
      );
}

/// Data demo mengikuti prototipe. TODO(backend): feed asli dari
/// pengecekan chapter baru per sumber.
const _seedUpdates = [
  UpdateEntry(dateGroup: 'Hari ini', title: 'Neon Samurai', src: 'MangaVerse', hue: 190, ch: 78, time: '1j'),
  UpdateEntry(dateGroup: 'Hari ini', title: 'Echoes of the Void', src: 'MangaVerse', hue: 265, ch: 42, time: '4j'),
  UpdateEntry(dateGroup: 'Kemarin', title: 'Starlight Requiem', src: 'AsuraToons', hue: 300, ch: 23, time: '18j'),
  UpdateEntry(dateGroup: 'Kemarin', title: 'Garden of Ashes', src: 'KomikStation', hue: 130, ch: 5, time: '22j'),
];

class UpdatesNotifier extends Notifier<List<UpdateEntry>> {
  @override
  List<UpdateEntry> build() => _seedUpdates;

  /// Cek chapter baru. Timing prototipe ~1.2s.
  /// TODO(backend): panggil refresh library sungguhan per sumber aktif.
  Future<void> refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
  }
}

final updatesProvider =
    NotifierProvider<UpdatesNotifier, List<UpdateEntry>>(UpdatesNotifier.new);
