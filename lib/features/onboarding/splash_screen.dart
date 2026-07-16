import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_spinner.dart';
import '../../core/widgets/logo_reveal.dart';
import '../../core/widgets/wave_background.dart';
import '../../data/bookmarks_state.dart';
import '../../data/history_state.dart';
import '../../data/library_state.dart';
import '../home/home_shell.dart';
import '../auth/auth_repository.dart';
import 'login_screen.dart';

/// Splash — spek 03: brand moment ~5 detik sambil cek sesi auth DAN
/// (kalau sesi valid) mulai sinkron data dari cloud, bukan cuma nunggu
/// diam. Sesi valid → langsung ke Library (skip Login & Sync); tidak →
/// Login.
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
    // Delay brand moment mulai dihitung dari sekarang, paralel dengan cek
    // sesi (`restoreSession` sendiri cepat/sinkron) supaya durasinya tidak
    // ketambahan waktu cek sesi.
    final delay = Future<void>.delayed(const Duration(milliseconds: 5000));
    final user = await ref.read(authControllerProvider.notifier).restoreSession();

    if (user != null) {
      // Baca provider-provider ini sekarang (bukan nunggu splash kelar) —
      // listener Firestore-nya nempel begitu provider pertama kali dibaca,
      // jadi sisa waktu splash (~5 detik) beneran dipakai buat narik data
      // dari cloud, bukan sekadar animasi kosong. Begitu user sampai di
      // Library/History, datanya idealnya sudah (atau hampir) siap.
      ref.read(libraryProvider);
      ref.read(historyProvider);
      ref.read(collectionsProvider);
      ref.read(bookmarksProvider);
    }

    await delay;
    if (!mounted) return;

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
            colors: [Color(0xFF0D1C2E), AppColors.bg],
          ),
        ),
        child: Stack(
          children: [
            const Align(
              alignment: Alignment.bottomCenter,
              child: WaveBackground(height: 120),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LogoReveal(
                    size: 88,
                    shadow: BoxShadow(
                      color: AppColors.fabShadow,
                      offset: Offset(0, 20),
                      blurRadius: 50,
                      spreadRadius: -12,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Kizen',
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
                padding: EdgeInsets.only(bottom: 88),
                child: AppSpinner(size: 26, strokeWidth: 2.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
