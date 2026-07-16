import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_mark.dart';

/// Riak ombak yang mengecil & memudar sambil logo Kizen memudar-masuk di
/// tengahnya — kesan "ombak menjadi ikon", sekali main saat Splash tampil.
class LogoReveal extends StatefulWidget {
  const LogoReveal({
    super.key,
    required this.size,
    this.shadow,
    this.duration = const Duration(milliseconds: 1900),
  });

  final double size;
  final BoxShadow? shadow;
  final Duration duration;

  @override
  State<LogoReveal> createState() => _LogoRevealState();
}

class _LogoRevealState extends State<LogoReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Riak: besar & jelas → mengecil & memudar di 0–0.65.
    final rippleT = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.65, curve: Curves.easeOut),
    );
    // Logo: memudar-masuk + scale-in menyusul, tumpang-tindih di tengah riak.
    final logoT = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.85, curve: Curves.easeOutBack),
    );
    final logoOpacityT = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.7, curve: Curves.easeIn),
    );

    final ripplePad = widget.size * 0.9;
    return SizedBox(
      width: widget.size + ripplePad,
      height: widget.size + ripplePad,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: 1 - rippleT.value,
                child: CustomPaint(
                  size: Size.square(widget.size + ripplePad),
                  painter: _RippleWavePainter(
                    t: rippleT.value,
                    baseRadius: widget.size / 2,
                  ),
                ),
              ),
              Opacity(
                opacity: logoOpacityT.value.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.7 + 0.3 * logoT.value.clamp(0.0, 1.2),
                  child: AppMark(
                    size: widget.size,
                    radius: widget.size * 0.27,
                    shadow: widget.shadow,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 2 cincin riak dengan tepi bergelombang (bukan lingkaran sempurna) —
/// menggemakan motif ombak logo, mengecil dari luar menuju ukuran logo.
class _RippleWavePainter extends CustomPainter {
  _RippleWavePainter({required this.t, required this.baseRadius});

  final double t;
  final double baseRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    _ring(
      canvas,
      center,
      radius: baseRadius + (1 - t) * baseRadius * 0.85,
      waveAmp: 3 + (1 - t) * 4,
      waveCount: 7,
      phase: t * math.pi,
      color: AppColors.accentText.withValues(alpha: 0.55 * (1 - t) + 0.05),
      strokeWidth: 2,
    );
    _ring(
      canvas,
      center,
      radius: baseRadius + (1 - t) * baseRadius * 0.45,
      waveAmp: 2 + (1 - t) * 3,
      waveCount: 9,
      phase: -t * math.pi * 1.4,
      color: AppColors.accent.withValues(alpha: 0.6 * (1 - t) + 0.05),
      strokeWidth: 2.5,
    );
  }

  void _ring(
    Canvas canvas,
    Offset center, {
    required double radius,
    required double waveAmp,
    required int waveCount,
    required double phase,
    required Color color,
    required double strokeWidth,
  }) {
    final path = Path();
    const steps = 72;
    for (var i = 0; i <= steps; i++) {
      final angle = (i / steps) * 2 * math.pi;
      final r = radius + waveAmp * math.sin(waveCount * angle + phase);
      final point = center + Offset(math.cos(angle), math.sin(angle)) * r;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _RippleWavePainter oldDelegate) =>
      oldDelegate.t != t;
}
