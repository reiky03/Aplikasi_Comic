import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pola empty-state — spek 15: ikon di kotak rounded 96×96 (r26),
/// judul 17/700, deskripsi 13.5 textMuted, CTA opsional, tengah vertikal.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.ctaLabel,
    this.onCta,
    this.bottomPadding = 60,
  });

  /// Ikon 42px; warna di-force ke stroke empty-state (#3d3d4e).
  final Widget icon;
  final String title;

  /// Deskripsi; pakai [Text.rich]-style spans lewat widget kalau perlu
  /// highlight — di sini menerima [InlineSpan] via [description].
  final InlineSpan description;
  final String? ctaLabel;
  final VoidCallback? onCta;

  /// Prototipe memberi padding bawah ekstra (60) supaya terlihat
  /// di tengah area konten di atas bottom nav.
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(44, 0, 44, bottomPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.surfaceEmptyIcon,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Center(
                child: IconTheme(
                  data: const IconThemeData(
                    color: AppColors.emptyIcon,
                    size: 42,
                  ),
                  child: icon,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.jakarta(size: 17, weight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text.rich(
              description,
              textAlign: TextAlign.center,
              style: AppTypography.jakarta(
                size: 13.5,
                weight: FontWeight.w400,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
            if (ctaLabel != null) ...[
              const SizedBox(height: 22),
              SizedBox(
                height: 46,
                child: FilledButton(
                  onPressed: onCta,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: AppTypography.button,
                  ),
                  child: Text(ctaLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
