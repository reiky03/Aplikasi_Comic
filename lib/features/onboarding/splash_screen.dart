import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_mark.dart';
import '../../core/widgets/app_spinner.dart';
import '../home/home_shell.dart';
import '../auth/auth_repository.dart';
import 'login_screen.dart';

/// Splash — spek 03: brand moment ~1.7s sambil cek sesi auth.
/// Sesi valid → langsung ke Library (skip Login & Sync); tidak → Login.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    // Cek sesi berjalan paralel dengan brand moment 1.7s (timing prototipe).
    final results = await Future.wait<Object?>([
      ref.read(authControllerProvider.notifier).restoreSession(),
      Future<void>.delayed(const Duration(milliseconds: 1700)),
    ]);
    if (!mounted) return;

    final user = results.first as AuthUser?;
    if (user != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const HomeShell(),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          // CSS: radial-gradient(130% 90% at 50% 35%, #1b1730 0%, #0E0E13 65%)
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.1,
            stops: [0, 0.65],
            colors: [Color(0xFF1B1730), AppColors.bg],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppMark(
                    size: 88,
                    radius: 24,
                    shadow: BoxShadow(
                      color: AppColors.fabShadow,
                      offset: Offset(0, 20),
                      blurRadius: 50,
                      spreadRadius: -12,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'My Comic',
                    style: AppTypography.jakarta(
                      size: 27,
                      weight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Baca dari sumbermu, di mana saja',
                    style: AppTypography.jakarta(
                      size: 13,
                      weight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 60),
                child: AppSpinner(size: 26, strokeWidth: 2.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
