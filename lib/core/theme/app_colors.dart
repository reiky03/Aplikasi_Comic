import 'package:flutter/material.dart';

/// Token warna "My Comic" — dark-first, satu-satunya tema.
/// Sumber kebenaran: design_handoff_my_comic/01_design_system.md
abstract final class AppColors {
  /// Background layar/app.
  static const Color bg = Color(0xFF0E0E13);

  /// Cards, list rows, input fields, bottom sheets.
  static const Color surface = Color(0xFF16161E);

  /// Icon buttons di header (search/filter).
  static const Color surfaceAlt = Color(0xFF191922);

  /// Tag pills, track background progress bar.
  static const Color surfaceSunken = Color(0xFF20202B);

  /// Lingkaran background ikon empty-state.
  static const Color surfaceEmptyIcon = Color(0xFF161620);

  /// Border default card/row — rgba(255,255,255,0.06).
  static const Color border = Color(0x0FFFFFFF);

  /// Border icon-button, divider — rgba(255,255,255,0.1).
  static const Color borderStrong = Color(0x1AFFFFFF);

  /// Primary: tombol utama, pill tab aktif, FAB, nav icon aktif,
  /// progress bar, background teks highlight.
  static const Color accent = Color(0xFF7C5CFF);

  /// Links, label aktif, copy highlight, teks nav aktif.
  static const Color accentText = Color(0xFFB7A6FF);

  static const Color textPrimary = Color(0xFFECECF1);
  static const Color textSecondary = Color(0xFF9C9CAC);
  static const Color textMuted = Color(0xFF8C8C9C);

  /// Least-emphasis: nav inaktif, hint disabled.
  static const Color textFaint = Color(0xFF6D6D7C);

  /// Footnotes.
  static const Color textFaintest = Color(0xFF4D4D5C);

  /// Atribusi sumber di bawah judul.
  static const Color textFaintestAlt = Color(0xFF7B7B8B);

  /// Status "Normal"/"Session aktif", banner sukses, state download selesai.
  static const Color success = Color(0xFF34D399);

  /// Status "Membutuhkan WebView"/"Terbatas".
  static const Color warning = Color(0xFFF2B44C);
  static const Color warningAlt = Color(0xFFE0913A);

  /// Status "Gagal diakses", tombol/teks destruktif, sign-out.
  static const Color danger = Color(0xFFFF7A93);
  static const Color dangerAlt = Color(0xFFFF6B85);

  /// Tint background tombol destruktif — rgba(255,122,147,0.08–0.14).
  static const Color dangerBg = Color(0x14FF7A93); // alpha 0.08
  static const Color dangerBgStrong = Color(0x24FF7A93); // alpha 0.14

  /// Drag handle bottom sheet — rgba(255,255,255,0.2).
  static const Color sheetDragHandle = Color(0x33FFFFFF);

  /// Gradient aksen: logo mark, ikon splash, FAB, avatar.
  /// CSS: linear-gradient(150deg, #8A6BFF, #5B3EDE)
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment(-0.5, -0.87),
    end: Alignment(0.5, 0.87),
    colors: [Color(0xFF8A6BFF), Color(0xFF5B3EDE)],
  );

  /// Background wash khusus layar Splash & Login.
  /// CSS: radial #14131C → #08080B
  static const RadialGradient bgGradientSplash = RadialGradient(
    center: Alignment.topCenter,
    radius: 1.2,
    colors: [Color(0xFF14131C), Color(0xFF08080B)],
  );
}
