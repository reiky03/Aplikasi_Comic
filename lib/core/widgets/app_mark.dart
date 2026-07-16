import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Logo mark "Kizen": kotak gradient + glyph 4 panel komik putih
/// (persis SVG prototipe, viewBox 44).
class AppMark extends StatelessWidget {
  const AppMark({
    super.key,
    required this.size,
    required this.radius,
    this.shadow,
  });

  final double size;
  final double radius;
  final BoxShadow? shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow == null ? null : [shadow!],
      ),
      child: Center(
        child: CustomPaint(
          size: Size.square(size / 2),
          painter: const _ComicPanelsPainter(),
        ),
      ),
    );
  }
}

class _ComicPanelsPainter extends CustomPainter {
  const _ComicPanelsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 44;
    void panel(double x, double y, double w, double h, double opacity) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x * s, y * s, w * s, h * s),
          Radius.circular(3 * s),
        ),
        paint,
      );
    }

    panel(8, 7, 12, 16, 1);
    panel(23, 7, 13, 9, 0.82);
    panel(23, 19, 13, 18, 1);
    panel(8, 26, 12, 11, 0.82);
  }

  @override
  bool shouldRepaint(_ComicPanelsPainter oldDelegate) => false;
}
