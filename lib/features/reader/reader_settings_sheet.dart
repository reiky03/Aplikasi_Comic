import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/reader_settings.dart';

/// Sheet "Pengaturan Reader" — spek 13. Semua nilai global & persisten.
void showReaderSettingsSheet(BuildContext context, {VoidCallback? onChanged}) {
  showAppSheet<void>(
    context,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final settings = ref.watch(readerSettingsProvider);
        void update(ReaderSettings next) {
          ref.read(readerSettingsProvider.notifier).update(next);
          onChanged?.call();
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSheetTitle('Pengaturan Reader', bottomGap: 18),
            _sectionLabel('Arah baca'),
            const SizedBox(height: 8),
            AppSegmentedControl(
              items: const [
                AppSegmentItem(label: 'Webtoon', icon: LucideIcons.arrowDown),
                AppSegmentItem(label: 'Halaman', icon: LucideIcons.arrowRight),
                AppSegmentItem(
                    label: 'Manga R→L', icon: LucideIcons.arrowLeft),
              ],
              selectedIndex: settings.direction.index,
              onSelect: (i) => update(
                settings.copyWith(direction: ReadingDirection.values[i]),
              ),
            ),
            const SizedBox(height: 18),
            _sectionLabel('Warna latar'),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final color in const [
                  Color(0xFF000000),
                  Color(0xFF0E0E13),
                  Color(0xFF1A1206),
                  Color(0xFFF5F0E6),
                ]) ...[
                  InkWell(
                    onTap: () => update(settings.copyWith(bg: color)),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          width: 2,
                          color: settings.bg == color
                              ? AppColors.accent
                              : const Color(0x24FFFFFF),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ],
            ),
            const SizedBox(height: 20),
            _sliderRow(
              label: 'Jarak antar halaman',
              valueLabel: '${settings.gap}px',
              value: settings.gap.toDouble(),
              min: 0,
              max: 30,
              onChanged: (v) => update(settings.copyWith(gap: v.round())),
            ),
            const SizedBox(height: 18),
            _sliderRow(
              label: 'Kecerahan',
              valueLabel: '${settings.brightness}%',
              value: settings.brightness.toDouble(),
              min: 30,
              max: 100,
              onChanged: (v) =>
                  update(settings.copyWith(brightness: v.round())),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Layar tetap menyala',
                      style: AppTypography.jakarta(
                          size: 13.5, weight: FontWeight.w600),
                    ),
                  ),
                  AppPillSwitch(
                    value: settings.keepScreenOn,
                    onChanged: (v) =>
                        update(settings.copyWith(keepScreenOn: v)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

Widget _sectionLabel(String text) => Text(
      text,
      style: AppTypography.jakarta(
        size: 12,
        weight: FontWeight.w700,
        color: AppColors.textMuted,
      ),
    );

Widget _sliderRow({
  required String label,
  required String valueLabel,
  required double value,
  required double min,
  required double max,
  required ValueChanged<double> onChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              style:
                  AppTypography.jakarta(size: 13.5, weight: FontWeight.w600),
            ),
          ),
          Text(
            valueLabel,
            style: AppTypography.jakarta(
              size: 12,
              weight: FontWeight.w700,
              color: AppColors.accentText,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      SliderTheme(
        data: const SliderThemeData(
          trackHeight: 4,
          activeTrackColor: AppColors.accent,
          inactiveTrackColor: AppColors.surfaceSunken,
          thumbColor: Colors.white,
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
          overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
          padding: EdgeInsets.zero,
        ),
        child: Slider(value: value, min: min, max: max, onChanged: onChanged),
      ),
    ],
  );
}
