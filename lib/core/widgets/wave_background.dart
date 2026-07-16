import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Gelombang animasi tipis (motif ombak logo Kizen) — looping halus,
/// dipakai sebagai lapisan dekoratif di belakang konten Splash.
class WaveBackground extends StatefulWidget {
  const WaveBackground({super.key, this.height = 240});

  final double height;

  @override
  State<WaveBackground> createState() => _WaveBackgroundState();
}

class _WaveBackgroundState extends State<WaveBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _WavePainter(_controller.value),
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.t);

  final double t;

  static const _tau = 2 * math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    _layer(
      canvas,
      size,
      phase: t * _tau,
      amplitude: 12,
      waveLength: size.width / 1.1,
      baseline: size.height * 0.60,
      color: AppColors.accent.withValues(alpha: 0.09),
    );
    _layer(
      canvas,
      size,
      phase: t * _tau + math.pi / 2,
      amplitude: 9,
      waveLength: size.width / 0.8,
      baseline: size.height * 0.74,
      color: AppColors.accentText.withValues(alpha: 0.08),
    );
    _layer(
      canvas,
      size,
      phase: -t * _tau + math.pi,
      amplitude: 16,
      waveLength: size.width / 1.4,
      baseline: size.height * 0.88,
      color: AppColors.accent.withValues(alpha: 0.13),
    );
  }

  void _layer(
    Canvas canvas,
    Size size, {
    required double phase,
    required double amplitude,
    required double waveLength,
    required double baseline,
    required Color color,
  }) {
    final path = Path()..moveTo(0, size.height);
    path.lineTo(0, baseline);
    const steps = 48;
    for (var i = 0; i <= steps; i++) {
      final x = size.width * i / steps;
      final y = baseline + amplitude * math.sin((x / waveLength) * _tau + phase);
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => oldDelegate.t != t;
}
