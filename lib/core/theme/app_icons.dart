import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Mapping ikon "Kizen" → Lucide (outline, stroke ~2, rounded caps).
/// Sumber kebenaran: design_handoff_my_comic/01_design_system.md → Iconography.
abstract final class AppIcons {
  // Tab bottom nav — ikon Library pakai glyph custom dua-bar
  // (LibraryGlyph di core/widgets) sesuai prototipe; ini fallback IconData.
  static const IconData library = LucideIcons.galleryVerticalEnd;
  static const IconData updates = LucideIcons.rotateCcw;
  static const IconData history = LucideIcons.clock;
  static const IconData browse = LucideIcons.compass;
  static const IconData settings = LucideIcons.settings;

  // Aksi umum
  static const IconData search = LucideIcons.search;
  static const IconData filter = LucideIcons.slidersHorizontal;
  static const IconData add = LucideIcons.plus;
  static const IconData back = LucideIcons.chevronLeft;
  static const IconData forward = LucideIcons.chevronRight;
  static const IconData more = LucideIcons.ellipsisVertical;
  static const IconData close = LucideIcons.x;

  // Konten & status
  static const IconData bookmark = LucideIcons.bookmark;
  static const IconData download = LucideIcons.arrowDownToLine;
  static const IconData downloaded = LucideIcons.check;
  static const IconData delete = LucideIcons.trash2;
  static const IconData edit = LucideIcons.pencil;
  static const IconData refresh = LucideIcons.refreshCw;
  static const IconData globe = LucideIcons.globe;
  static const IconData secureSession = LucideIcons.shieldCheck;
  static const IconData lock = LucideIcons.lock;
  static const IconData errorTriangle = LucideIcons.triangleAlert;
  static const IconData errorCircle = LucideIcons.circleAlert;
  static const IconData play = LucideIcons.play;
  static const IconData readerSettings = LucideIcons.settings2;
}
