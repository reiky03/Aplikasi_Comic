import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Spinner ring prototipe: track lingkaran penuh (opasitas rendah)
/// + arc solid seperempat lingkaran yang berputar (~0.8s linear).
class AppSpinner extends StatefulWidget {
  const AppSpinner({
    super.key,
    this.size = 26,
    this.strokeWidth = 2.5,
    this.color = const Color(0xFF8A6BFF),
    this.trackColor,
    this.animating = true,
  });

  final double size;
  final double strokeWidth;
  final Color color;

  /// Default: [color] pada ~25% opasitas.
  final Color? trackColor;

  /// false = ring statis (mis. state error sync).
  final bool animating;

  @override
  State<AppSpinner> createState() => _AppSpinnerState();
}

class _AppSpinnerState extends State<AppSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animating) _controller.repeat();
  }

  @override
  void didUpdateWidget(AppSpinner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animating && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animating && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _RingPainter(
          color: widget.color,
          trackColor: widget.trackColor ??
              widget.color.withValues(alpha: AppMotion.spinnerTrackOpacity),
          strokeWidth: widget.strokeWidth,
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inset = rect.deflate(strokeWidth / 2);
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawOval(inset, track);

    // Arc atas (posisi jarum jam 12 → 3) meniru border-top-color CSS.
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(inset, -math.pi / 2 - math.pi / 4, math.pi / 2, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      color != oldDelegate.color ||
      trackColor != oldDelegate.trackColor ||
      strokeWidth != oldDelegate.strokeWidth;
}
