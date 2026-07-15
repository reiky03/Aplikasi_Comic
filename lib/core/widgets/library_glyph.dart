import 'package:flutter/widgets.dart';

/// Ikon "Library" prototipe: dua bar vertikal rounded
/// (rect 3,4 7×16 r1.5 + rect 14,4 7×16 r1.5 pada viewBox 24).
/// Tidak ada padanan persis di Lucide, jadi digambar manual.
class LibraryGlyph extends StatelessWidget {
  const LibraryGlyph({
    super.key,
    required this.size,
    required this.color,
    this.strokeWidth = 1.9,
  });

  final double size;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _LibraryGlyphPainter(color: color, strokeWidth: strokeWidth),
    );
  }
}

class _LibraryGlyphPainter extends CustomPainter {
  const _LibraryGlyphPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * scale
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    RRect bar(double x) => RRect.fromRectAndRadius(
          Rect.fromLTWH(x * scale, 4 * scale, 7 * scale, 16 * scale),
          Radius.circular(1.5 * scale),
        );
    canvas.drawRRect(bar(3), paint);
    canvas.drawRRect(bar(14), paint);
  }

  @override
  bool shouldRepaint(_LibraryGlyphPainter oldDelegate) =>
      color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
}
