import 'package:flutter/widgets.dart';

/// Spacing, radii, dan ukuran komponen "My Comic".
/// Sumber kebenaran: design_handoff_my_comic/01_design_system.md
abstract final class AppDimens {
  /// Padding horizontal layar (18–20px).
  static const double screenPaddingH = 20;
  static const double screenPaddingHTight = 18;

  // --- Radii ---

  /// Card/row standar (13–16px).
  static const double radiusCard = 16;
  static const double radiusRow = 14;
  static const double radiusRowSmall = 13;

  /// Icon-button kecil (10–13px).
  static const double radiusIconButton = 12;
  static const double radiusIconButtonSmall = 10;
  static const double radiusIconButtonLarge = 13;

  /// Tombol primary/secondary (12–14px).
  static const double radiusButton = 13;

  /// Bottom sheet — 24px sudut atas saja.
  static const double radiusSheet = 24;

  /// FAB.
  static const double radiusFab = 19;

  /// Container pill bottom nav.
  static const double radiusNav = 20;

  // --- Tombol ---

  /// Tinggi tombol (44–56px).
  static const double buttonHeight = 52;
  static const double buttonHeightSmall = 44;
  static const double buttonHeightLarge = 56;

  /// Hit area minimum elemen tappable.
  static const double minTapTarget = 44;

  // --- FAB ---
  static const double fabSize = 58;
  static const double fabRight = 20;

  /// Jarak FAB dari bawah layar (bebas dari floating bottom nav).
  static const double fabBottom = 104;

  // --- Bottom nav (pill mengambang) ---
  static const EdgeInsets navMargin = EdgeInsets.fromLTRB(10, 8, 10, 22);
  static const EdgeInsets navPadding =
      EdgeInsets.symmetric(vertical: 7, horizontal: 6);

  // --- Bottom sheet ---
  /// Padding sheet: 14px atas, 20px samping, 34px bawah
  /// (ruang ekstra untuk gesture bar).
  static const EdgeInsets sheetPadding = EdgeInsets.fromLTRB(20, 14, 20, 34);
  static const Size sheetDragHandleSize = Size(40, 4);
  static const double sheetDragHandleGap = 16;

  // --- Grid & cover ---

  /// Rasio aspek cover komik — 2:3 di semua tempat.
  static const double coverAspectRatio = 2 / 3;

  /// Grid library/discover: 3 kolom, gap 14px.
  static const int gridColumns = 3;
  static const double gridGap = 14;

  // --- Ikon ---

  /// Ukuran ikon tipikal 16–22px, stroke ~2.
  static const double iconSize = 20;
  static const double iconSizeSmall = 16;
  static const double iconSizeLarge = 22;

  /// Border default 1px.
  static const double borderWidth = 1;
}
