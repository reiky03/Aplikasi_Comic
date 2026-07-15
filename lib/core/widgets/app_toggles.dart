import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pill switch — spek 15: track off #2a2a35 / on accent, knob putih.
/// Dua ukuran di prototipe: 44×26 (Settings) dan 46×27 (sheet bahasa/reader).
class AppPillSwitch extends StatelessWidget {
  const AppPillSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 46,
    this.height = 27,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final knob = height - 6;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.ease,
        width: width,
        height: height,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? AppColors.accent : AppColors.switchTrackOff,
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.ease,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: knob,
            height: knob,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class AppSegmentItem {
  const AppSegmentItem({required this.label, this.icon});

  final String label;
  final IconData? icon;
}

/// Segmented buttons — spek 15: tiap segmen rounded rect sendiri, gap 7–8px.
/// Aktif: bg rgba(124,92,255,.16) + border rgba(124,92,255,.5) + teks accentText;
/// inaktif: bg #1E1E28, border transparan, teks textSecondary.
class AppSegmentedControl extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    this.height = 56,
    this.gap = 7,
  });

  final List<AppSegmentItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final double height;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(child: _segment(i)),
        ],
      ],
    );
  }

  Widget _segment(int i) {
    final item = items[i];
    final active = i == selectedIndex;
    final color = active ? AppColors.accentText : AppColors.textSecondary;
    return InkWell(
      onTap: () => onSelect(i),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: active ? AppColors.segmentActiveBg : AppColors.rowHighlight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppColors.segmentActiveBorder : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (item.icon != null) ...[
              Icon(item.icon, size: 17, color: color),
              const SizedBox(height: 5),
            ],
            Text(
              item.label,
              style: AppTypography.jakarta(
                size: 11.5,
                weight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
