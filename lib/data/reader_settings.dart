import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firestore_scope.dart';

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

  /// Mapping ke `users/{uid}/settings/reader` — lihat docs/DATABASE.md.
  Map<String, dynamic> toMap() => {
        'direction': direction.name,
        'bg': '#${bg.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
        'gap': gap,
        'brightness': brightness,
        'keepScreenOn': keepScreenOn,
      };

  factory ReaderSettings.fromMap(Map<String, dynamic> map) {
    final bgHex = map['bg'] as String?;
    return ReaderSettings(
      direction: ReadingDirection.values.firstWhere(
        (d) => d.name == map['direction'],
        orElse: () => ReadingDirection.vertical,
      ),
      bg: bgHex == null
          ? const Color(0xFF000000)
          : Color(int.parse('FF${bgHex.replaceFirst('#', '')}', radix: 16)),
      gap: (map['gap'] as num?)?.toInt() ?? 10,
      brightness: (map['brightness'] as num?)?.toInt() ?? 100,
      keepScreenOn: map['keepScreenOn'] as bool? ?? true,
    );
  }
}

class ReaderSettingsNotifier extends Notifier<ReaderSettings> {
  static const _kDirection = 'reader_direction';
  static const _kBg = 'reader_bg';
  static const _kGap = 'reader_gap';
  static const _kBrightness = 'reader_brightness';
  static const _kKeepOn = 'reader_keep_on';

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  DocumentReference<Map<String, dynamic>>? get _doc =>
      FirestoreScope.collection('settings')?.doc('reader');

  @override
  ReaderSettings build() {
    ref.onDispose(() => _sub?.cancel());
    final doc = _doc;
    if (doc == null) {
      _hydrate();
      return const ReaderSettings();
    }
    _sub = doc.snapshots().listen((snap) {
      final data = snap.data();
      if (data != null) state = ReaderSettings.fromMap(data);
    });
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

  Future<void> _persist(ReaderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kDirection, settings.direction.index);
    await prefs.setInt(_kBg, settings.bg.toARGB32());
    await prefs.setInt(_kGap, settings.gap);
    await prefs.setInt(_kBrightness, settings.brightness);
    await prefs.setBool(_kKeepOn, settings.keepScreenOn);
  }

  Future<void> update(ReaderSettings settings) async {
    state = settings;
    final doc = _doc;
    if (doc == null) {
      await _persist(settings);
      return;
    }
    await doc.set(settings.toMap(), SetOptions(merge: true));
  }
}

final readerSettingsProvider =
    NotifierProvider<ReaderSettingsNotifier, ReaderSettings>(
        ReaderSettingsNotifier.new);
