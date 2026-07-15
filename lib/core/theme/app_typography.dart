import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Text styles "My Comic".
/// UI: Plus Jakarta Sans (400/500/600/700/800).
/// Mono: JetBrains Mono (400/500) — hanya untuk URL/domain.
/// Sumber kebenaran: design_handoff_my_comic/01_design_system.md
abstract final class AppTypography {
  static TextStyle _jakarta({
    required double size,
    required FontWeight weight,
    double? letterSpacing,
    double? height,
    Color color = AppColors.textPrimary,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
    );
  }

  /// Judul layar (H1) — mis. "Library", "Jelajahi".
  static TextStyle get screenTitle =>
      _jakarta(size: 26, weight: FontWeight.w800, letterSpacing: -0.5);

  /// Nama app di Splash/Login (27–29px).
  static TextStyle get appName =>
      _jakarta(size: 28, weight: FontWeight.w800, letterSpacing: -0.55);

  /// Header bottom sheet.
  static TextStyle get sheetTitle =>
      _jakarta(size: 17, weight: FontWeight.w800);

  /// Judul card/row — judul komik, nama sumber (13.5–14.5px).
  static TextStyle get rowTitle => _jakarta(size: 14, weight: FontWeight.w700);
  static TextStyle get rowTitleSmall =>
      _jakarta(size: 13.5, weight: FontWeight.w700);
  static TextStyle get rowTitleLarge =>
      _jakarta(size: 14.5, weight: FontWeight.w700);

  /// Body/deskripsi (13–13.5px, 400–500, line-height 1.5–1.6).
  static TextStyle get body => _jakarta(
        size: 13.5,
        weight: FontWeight.w400,
        height: 1.55,
        color: AppColors.textSecondary,
      );
  static TextStyle get bodyMedium => _jakarta(
        size: 13,
        weight: FontWeight.w500,
        height: 1.5,
        color: AppColors.textSecondary,
      );

  /// Label kecil/meta — label chapter, timestamp, teks status (10.5–12.5px).
  static TextStyle get meta => _jakarta(
        size: 12,
        weight: FontWeight.w600,
        color: AppColors.textSecondary,
      );
  static TextStyle get metaSmall => _jakarta(
        size: 11,
        weight: FontWeight.w600,
        color: AppColors.textSecondary,
      );
  static TextStyle get metaBold => _jakarta(
        size: 11.5,
        weight: FontWeight.w700,
        color: AppColors.textSecondary,
      );

  /// Section eyebrow — uppercase, mis. "INDONESIA · 3".
  /// Terapkan uppercase pada string-nya sendiri.
  static TextStyle get eyebrow => _jakarta(
        size: 11.5,
        weight: FontWeight.w800,
        letterSpacing: 0.6,
        color: AppColors.textFaint,
      );

  /// Label tombol (13.5–15px, 700).
  static TextStyle get button =>
      _jakarta(size: 14.5, weight: FontWeight.w700);
  static TextStyle get buttonSmall =>
      _jakarta(size: 13.5, weight: FontWeight.w700);
  static TextStyle get buttonLarge =>
      _jakarta(size: 15, weight: FontWeight.w700);

  /// Label bottom nav — caption 10px di bawah ikon (non-interaktif;
  /// hit area tombol nav tetap minimal 44×44).
  static TextStyle get navLabel => _jakarta(
        size: 10,
        weight: FontWeight.w600,
        color: AppColors.textFaint,
      );

  /// Monospace untuk URL/domain (subtitle daftar sumber, address bar,
  /// input URL).
  static TextStyle mono({
    double size = 12.5,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.textSecondary,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  /// Style umum Plus Jakarta Sans untuk kebutuhan di luar preset.
  static TextStyle jakarta({
    required double size,
    required FontWeight weight,
    double? letterSpacing,
    double? height,
    Color color = AppColors.textPrimary,
  }) =>
      _jakarta(
        size: size,
        weight: weight,
        letterSpacing: letterSpacing,
        height: height,
        color: color,
      );
}
