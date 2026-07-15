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

  // --- Token komponen dari 15_shared_components.md / prototipe ---

  /// Scrim bottom sheet — rgba(0,0,0,0.55).
  static const Color scrim = Color(0x8C000000);

  /// Border atas bottom sheet — rgba(255,255,255,0.08).
  static const Color sheetTopBorder = Color(0x14FFFFFF);

  /// Divider antar row opsi di sheet — rgba(255,255,255,0.05).
  static const Color sheetRowDivider = Color(0x0DFFFFFF);

  /// Background toast.
  static const Color toastBg = Color(0xFF26262F);

  /// Highlight hover/pressed row menu & bg segment inaktif.
  static const Color rowHighlight = Color(0xFF1E1E28);

  /// Warna ikon di row menu konteks.
  static const Color menuIcon = Color(0xFFC9C9D6);

  /// Stroke ikon empty-state.
  static const Color emptyIcon = Color(0xFF3D3D4E);

  /// Track pill switch posisi off (juga bg tombol disabled "Buat").
  static const Color switchTrackOff = Color(0xFF2A2A35);

  /// Segment aktif — rgba(124,92,255,0.16) bg, rgba(124,92,255,0.5) border.
  static const Color segmentActiveBg = Color(0x297C5CFF);
  static const Color segmentActiveBorder = Color(0x807C5CFF);

  /// Border/bg affordance "Buat koleksi baru" (dashed) —
  /// rgba(124,92,255,0.4) / rgba(124,92,255,0.06).
  static const Color accentBorderFaint = Color(0x667C5CFF);
  static const Color accentBgFaint = Color(0x0F7C5CFF);

  /// Border tombol hapus koleksi — rgba(255,122,147,0.25).
  static const Color dangerBorder = Color(0x40FF7A93);

  /// Shadow FAB — rgba(124,92,255,0.7).
  static const Color fabShadow = Color(0xB37C5CFF);

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
