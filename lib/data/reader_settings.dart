import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Arah baca.
enum ReadingDirection { vertical, horizontal, rtl }

/// Preferensi Reader — global per user, persisten lintas sesi.
class ReaderSettings {
  const ReaderSettings({
    this.direction = ReadingDirection.vertical,
    this.bg = const Color(0xFF000000),
    this.gap = 10,
    this.brightness = 100,
    this.keepScreenOn = true,
  });

  final ReadingDirection direction;

  /// Warna latar baca: #000000 / #0E0E13 / #1a1206 / #f5f0e6.
  final Color bg;

  /// Jarak antar halaman (webtoon), 0–30 px.
  final int gap;

  /// Kecerahan baca 30–100 (%).
  final int brightness;

  final bool keepScreenOn;

  bool get isWebtoon => direction == ReadingDirection.vertical;

  ReaderSettings copyWith({
    ReadingDirection? direction,
    Color? bg,
    int? gap,
    int? brightness,
    bool? keepScreenOn,
  }) {
    return ReaderSettings(
      direction: direction ?? this.direction,
      bg: bg ?? this.bg,
      gap: gap ?? this.gap,
      brightness: brightness ?? this.brightness,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    );
  }
}

class ReaderSettingsNotifier extends Notifier<ReaderSettings> {
  static const _kDirection = 'reader_direction';
  static const _kBg = 'reader_bg';
  static const _kGap = 'reader_gap';
  static const _kBrightness = 'reader_brightness';
  static const _kKeepOn = 'reader_keep_on';

  @override
  ReaderSettings build() {
    _hydrate();
    return const ReaderSettings();
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final dirIndex = prefs.getInt(_kDirection);
    final bgValue = prefs.getInt(_kBg);
    state = ReaderSettings(
      direction: dirIndex == null
          ? ReadingDirection.vertical
          : ReadingDirection.values[dirIndex],
      bg: bgValue == null ? const Color(0xFF000000) : Color(bgValue),
      gap: prefs.getInt(_kGap) ?? 10,
      brightness: prefs.getInt(_kBrightness) ?? 100,
      keepScreenOn: prefs.getBool(_kKeepOn) ?? true,
    );
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kDirection, state.direction.index);
    await prefs.setInt(_kBg, state.bg.toARGB32());
    await prefs.setInt(_kGap, state.gap);
    await prefs.setInt(_kBrightness, state.brightness);
    await prefs.setBool(_kKeepOn, state.keepScreenOn);
  }

  void update(ReaderSettings settings) {
    state = settings;
    _persist();
  }
}

final readerSettingsProvider =
    NotifierProvider<ReaderSettingsNotifier, ReaderSettings>(
        ReaderSettingsNotifier.new);
