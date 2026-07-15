import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Toggle demo/QA dari Setelan (prototipe) — memaksa empty state
/// untuk pengujian. Rekomendasi spek: gate di build internal/debug
/// sebelum rilis publik.
class DemoFlag extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final demoLibEmptyProvider = NotifierProvider<DemoFlag, bool>(DemoFlag.new);
final demoHistEmptyProvider = NotifierProvider<DemoFlag, bool>(DemoFlag.new);
final demoBrowseEmptyProvider = NotifierProvider<DemoFlag, bool>(DemoFlag.new);
final demoRepoEmptyProvider = NotifierProvider<DemoFlag, bool>(DemoFlag.new);

/// Label tema aktif — dekoratif (dark-first; Terang/Sistem menyusul).
class ThemeModeLabel extends Notifier<String> {
  @override
  String build() => 'Gelap';

  void set(String label) => state = label;
}

final themeModeLabelProvider =
    NotifierProvider<ThemeModeLabel, String>(ThemeModeLabel.new);
