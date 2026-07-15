import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_spinner.dart';
import '../home/home_shell.dart';
import '../sync/sync_service.dart';

/// Sync — spek 03: loading pasca-login (library, sumber, riwayat).
/// Sukses → Library. Gagal → tetap di sini dengan "Coba Lagi" +
/// "Lanjutkan offline" (state error produksi sesuai instruksi spek,
/// menggantikan auto-lanjut prototipe).
class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  Future<void> _sync() async {
    setState(() => _failed = false);
    try {
      await ref.read(syncServiceProvider).syncAll();
      if (!mounted) return;
      _goHome();
    } on Exception {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: AppSpinner(
                      size: 64,
                      strokeWidth: 3,
                      trackColor: const Color(0x2E7C5CFF), // .18
                      animating: !_failed,
                    ),
                  ),
                  if (_failed)
                    const Icon(AppIcons.errorTriangle,
                        size: 24, color: AppColors.danger)
                  else
                    const CustomPaint(
                      size: Size.square(24),
                      painter: _SyncArrowsPainter(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _failed ? 'Gagal sync, coba lagi' : 'Menyinkronkan data…',
              style: AppTypography.jakarta(size: 17, weight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Mengambil library, sumber & riwayat',
              style: AppTypography.jakarta(
                size: 13,
                weight: FontWeight.w400,
                color: AppColors.textMuted,
              ),
            ),
            if (_failed) ...[
              const SizedBox(height: 26),
              SizedBox(
                height: 46,
                child: FilledButton(
                  onPressed: _sync,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: AppTypography.button,
                  ),
                  child: const Text('Coba Lagi'),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: _goHome,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentText,
                  textStyle: AppTypography.jakarta(
                    size: 13.5,
                    weight: FontWeight.w600,
                  ),
                ),
                child: const Text('Lanjutkan offline'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Glyph panah sinkronisasi dua arah dari prototipe (viewBox 24):
/// dua arc + dua kepala panah, stroke 2.2 rounded.
class _SyncArrowsPainter extends CustomPainter {
  const _SyncArrowsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final paint = Paint()
      ..color = const Color(0xFF8A6BFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final rect = Rect.fromCircle(center: Offset(12 * s, 12 * s), radius: 9 * s);
    // M21 12a9 9 0 0 1-9 9  (kanan → bawah)
    canvas.drawArc(rect, 0, 0.5 * 3.1415926535, false, paint);
    // M3 12a9 9 0 0 1 9-9  (kiri → atas)
    canvas.drawArc(rect, 3.1415926535, 0.5 * 3.1415926535, false, paint);

    Path polyline(List<Offset> pts) {
      final p = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final pt in pts.skip(1)) {
        p.lineTo(pt.dx, pt.dy);
      }
      return p;
    }

    // M12 3l3 3-3 3
    canvas.drawPath(
      polyline([Offset(12 * s, 3 * s), Offset(15 * s, 6 * s), Offset(12 * s, 9 * s)]),
      paint,
    );
    // M12 21l-3-3 3-3
    canvas.drawPath(
      polyline([Offset(12 * s, 21 * s), Offset(9 * s, 18 * s), Offset(12 * s, 15 * s)]),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SyncArrowsPainter oldDelegate) => false;
}
