import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Buka bottom sheet dengan shell standar — spek 15_shared_components.md.
/// Scrim rgba(0,0,0,.55) tap-to-dismiss, slide-up 280ms cubic(.2,.8,.2,1).
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool menuStyle = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.scrim,
    isScrollControlled: true,
    useSafeArea: false,
    sheetAnimationStyle: const AnimationStyle(
      duration: AppMotion.sheetEnter,
      curve: AppMotion.sheetCurve,
      reverseDuration: Duration(milliseconds: 200),
    ),
    builder: (context) => AppSheetShell(menuStyle: menuStyle, child: builder(context)),
  );
}

/// Shell visual sheet: surface bg, radius 24 atas, border atas 1px,
/// drag handle 40×4, padding 14/20/34 (menu-style: 14/14/34).
class AppSheetShell extends StatelessWidget {
  const AppSheetShell({super.key, required this.child, this.menuStyle = false});

  final Widget child;

  /// true untuk sheet menu ikon-row (context menu, reader more menu):
  /// padding samping 14 dan tanpa judul.
  final bool menuStyle;

  @override
  Widget build(BuildContext context) {
    final basePadding = menuStyle
        ? const EdgeInsets.fromLTRB(14, 14, 14, 34)
        : AppDimens.sheetPadding;
    // Dorong sheet ke atas kalau keyboard muncul — tanpa ini, sheet yang
    // punya text field (mis. buat/edit koleksi) tertutup keyboard karena
    // posisinya tidak menyesuaikan `viewInsets` sama sekali. `AnimatedPadding`
    // (bukan padding statis langsung dari `viewInsets`) supaya transisinya
    // di-easing mulus, bukan lompat sekali jadi (kerasa jitter/patah).
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimens.radiusSheet),
          ),
          border: Border(
            top: BorderSide(color: AppColors.sheetTopBorder),
          ),
        ),
        padding: basePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: AppDimens.sheetDragHandleSize.width,
                height: AppDimens.sheetDragHandleSize.height,
                margin: const EdgeInsets.only(bottom: AppDimens.sheetDragHandleGap),
                decoration: BoxDecoration(
                  color: AppColors.sheetDragHandle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Sheet konfirmasi destruktif (hapus koleksi/sumber/repository/dll) —
/// judul + pesan + tombol Batal/konfirmasi. Kembalikan `true` kalau user
/// menekan tombol konfirmasi, `false` (bukan `null`) untuk batal/dismiss.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Hapus',
  String cancelLabel = 'Batal',
}) async {
  final result = await showAppSheet<bool>(
    context,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSheetTitle(title, bottomGap: 8),
        Text(
          message,
          style: AppTypography.jakarta(
            size: 13,
            weight: FontWeight.w400,
            height: 1.5,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => Navigator.pop(sheetContext, false),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderStrong),
                  ),
                  child: Text(
                    cancelLabel,
                    style: AppTypography.jakarta(
                      size: 14,
                      weight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () => Navigator.pop(sheetContext, true),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    confirmLabel,
                    style: AppTypography.jakarta(
                      size: 14,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Judul sheet 17/800, margin bawah 16.
class AppSheetTitle extends StatelessWidget {
  const AppSheetTitle(this.title, {super.key, this.bottomGap = 16});

  final String title;
  final double bottomGap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomGap),
      child: Text(title, style: AppTypography.sheetTitle),
    );
  }
}

/// Row opsi sheet (sort/tema/bahasa): label 14/600 + checkmark accent
/// saat aktif; divider tipis di atas row kecuali row pertama.
class AppSheetOptionRow extends StatelessWidget {
  const AppSheetOptionRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.showTopDivider = true,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool showTopDivider;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: showTopDivider
            ? const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.sheetRowDivider)),
              )
            : null,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.jakarta(size: 14, weight: FontWeight.w600),
              ),
            ),
            if (selected)
              const Icon(AppIcons.downloaded, size: 18, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

/// Row menu ikon (context menu / reader more menu):
/// ikon 19 + label 14/600, padding 14/10, radius 11, highlight saat ditekan.
class AppSheetMenuRow extends StatelessWidget {
  const AppSheetMenuRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  /// Override warna ikon (mis. hijau untuk "Tandai selesai").
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.danger : AppColors.menuIcon;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      highlightColor: AppColors.rowHighlight,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Row(
          children: [
            Icon(icon, size: 19, color: iconColor ?? color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: AppTypography.jakarta(
                  size: 14,
                  weight: FontWeight.w600,
                  color: destructive ? AppColors.danger : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
