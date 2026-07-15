import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'library_glyph.dart';

/// 5 tab root aplikasi.
enum AppTab { library, updates, history, browse, settings }

extension AppTabX on AppTab {
  String get label => switch (this) {
        AppTab.library => 'Library',
        AppTab.updates => 'Updates',
        AppTab.history => 'History',
        AppTab.browse => 'Jelajahi',
        AppTab.settings => 'Setelan',
      };
}

/// Bottom nav pill mengambang — spek 15_shared_components.md.
/// Persisten di 5 tab root; disembunyikan total di route pushed/full-screen.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.active,
    required this.onSelect,
  });

  final AppTab active;
  final ValueChanged<AppTab> onSelect;

  @override
  Widget build(BuildContext context) {
    // Margin bawah desain 22px; kalau safe-area device lebih besar
    // (gesture bar), pakai itu supaya nav tidak ketutup.
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomMargin = math.max(AppDimens.navMargin.bottom, bottomInset);

    return Padding(
      padding: AppDimens.navMargin.copyWith(bottom: bottomMargin),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusNav),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              offset: Offset(0, -4),
              blurRadius: 20,
              spreadRadius: -8,
            ),
          ],
        ),
        child: Padding(
          padding: AppDimens.navPadding,
          child: Row(
            children: [
              for (final tab in AppTab.values)
                Expanded(child: _NavItem(tab: tab, active: tab == active, onTap: () => onSelect(tab))),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.tab, required this.active, required this.onTap});

  final AppTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accentText : AppColors.textFaint;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusIconButton),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tab == AppTab.library)
              LibraryGlyph(size: 22, color: color)
            else
              Icon(_iconFor(tab), size: 22, color: color),
            const SizedBox(height: 3),
            Text(
              tab.label,
              style: AppTypography.jakarta(
                size: 10,
                weight: FontWeight.w700,
                letterSpacing: 0.1,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(AppTab tab) => switch (tab) {
        AppTab.library => AppIcons.library,
        AppTab.updates => AppIcons.updates,
        AppTab.history => AppIcons.history,
        AppTab.browse => AppIcons.browse,
        AppTab.settings => AppIcons.settings,
      };
}

/// Backdrop gradasi di belakang nav (prototipe: linear ke atas,
/// #0E0E13 62% → transparan) supaya konten scroll memudar di bawahnya.
class AppBottomNavBackdrop extends StatelessWidget {
  const AppBottomNavBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          stops: [0.62, 1],
          colors: [AppColors.bg, Color(0x000E0E13)],
        ),
      ),
      child: child,
    );
  }
}
