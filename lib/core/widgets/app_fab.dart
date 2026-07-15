import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';

/// FAB "tambah sumber" — hanya dirender di Jelajahi → Sumber Saya.
/// 58×58, radius 19 (squircle), accentGradient, shadow ungu.
/// Posisikan via Positioned(right: AppDimens.fabRight, bottom: AppDimens.fabBottom).
class AppFab extends StatelessWidget {
  const AppFab({super.key, required this.onTap, this.icon = LucideIcons.plus});

  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(AppDimens.radiusFab),
        boxShadow: const [
          BoxShadow(
            color: AppColors.fabShadow,
            offset: Offset(0, 14),
            blurRadius: 32,
            spreadRadius: -8,
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimens.radiusFab),
          child: SizedBox(
            width: AppDimens.fabSize,
            height: AppDimens.fabSize,
            child: Icon(icon, size: 26, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
