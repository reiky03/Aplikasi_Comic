import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Icon button header 40×40 r12 (`surfaceAlt`, ikon 19 warna #C9C9D6) —
/// dipakai di header Library, Jelajahi, dll.
class AppHeaderIconButton extends StatelessWidget {
  const AppHeaderIconButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 19, color: AppColors.menuIcon),
        ),
      ),
    );
  }
}
