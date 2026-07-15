import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_motion.dart';
import 'app_typography.dart';

export 'app_colors.dart';
export 'app_dimens.dart';
export 'app_icons.dart';
export 'app_motion.dart';
export 'app_typography.dart';

/// Tema "My Comic" — dark-first, satu-satunya tema.
/// Toggle tema terang di Settings masih dekoratif (TODO), sesuai handoff.
abstract final class AppTheme {
  /// Status bar: ikon terang di atas background gelap.
  static const SystemUiOverlayStyle systemOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  static ThemeData get dark {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);

    const colorScheme = ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: Colors.white,
      secondary: AppColors.accentText,
      onSecondary: AppColors.bg,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerHighest: AppColors.surfaceSunken,
      outline: AppColors.borderStrong,
      outlineVariant: AppColors.border,
      error: AppColors.danger,
      onError: AppColors.bg,
    );

    final textTheme =
        GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      textTheme: textTheme,
      dividerColor: AppColors.borderStrong,
      splashColor: Colors.white.withValues(alpha: 0.04),
      highlightColor: Colors.white.withValues(alpha: 0.04),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: systemOverlayStyle,
        titleTextStyle: AppTypography.screenTitle,
        iconTheme: const IconThemeData(
          color: AppColors.textPrimary,
          size: AppDimens.iconSize,
        ),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.textPrimary,
        size: AppDimens.iconSize,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeSlideUpPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeSlideUpPageTransitionsBuilder(),
          TargetPlatform.linux: FadeSlideUpPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeSlideUpPageTransitionsBuilder(),
          TargetPlatform.windows: FadeSlideUpPageTransitionsBuilder(),
        },
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimens.radiusSheet),
          ),
        ),
        showDragHandle: false,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.surfaceSunken,
        strokeWidth: AppMotion.spinnerStrokeWidth,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderStrong,
        thickness: AppDimens.borderWidth,
        space: AppDimens.borderWidth,
      ),
      scrollbarTheme: const ScrollbarThemeData(
        thumbVisibility: WidgetStatePropertyAll(false),
      ),
    );
  }
}
