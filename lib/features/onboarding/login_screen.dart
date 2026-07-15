import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_mark.dart';
import '../../core/widgets/app_toast.dart';
import '../auth/auth_repository.dart';
import 'sync_screen.dart';

/// SVG "G" Google multicolor dari prototipe.
const _googleLogoSvg = '''
<svg width="21" height="21" viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg"><path fill="#FFC107" d="M43.6 20.5H42V20H24v8h11.3C33.7 32.9 29.3 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3.1 0 5.9 1.2 8 3.1l5.7-5.7C34.5 6.1 29.5 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20 20-8.9 20-20c0-1.3-.1-2.3-.4-3.5z"/><path fill="#FF3D00" d="M6.3 14.7l6.6 4.8C14.7 15.1 19 12 24 12c3.1 0 5.9 1.2 8 3.1l5.7-5.7C34.5 6.1 29.5 4 24 4 16.3 4 9.7 8.3 6.3 14.7z"/><path fill="#4CAF50" d="M24 44c5.2 0 9.9-2 13.4-5.2l-6.2-5.2C29.2 35.1 26.7 36 24 36c-5.3 0-9.7-3.1-11.3-7.5l-6.5 5C9.5 39.6 16.2 44 24 44z"/><path fill="#1976D2" d="M43.6 20.5H42V20H24v8h11.3c-.8 2.2-2.2 4.1-4.1 5.6l6.2 5.2C41.7 35.5 44 30.2 44 24c0-1.3-.1-2.3-.4-3.5z"/></svg>
''';

/// Login — spek 03: satu-satunya pintu masuk, Google Sign-In saja.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _signingIn = false;

  Future<void> _login() async {
    if (_signingIn) return;
    setState(() => _signingIn = true);
    try {
      await ref.read(authControllerProvider.notifier).signIn();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const SyncScreen()),
      );
    } on AuthCancelledException {
      // User menutup dialog Google — bukan error.
    } on Exception catch (e) {
      if (!mounted) return;
      final message =
          e is AuthException ? e.message : 'Login gagal. Coba lagi.';
      AppToast.show(context, message);
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          // CSS: radial-gradient(120% 70% at 50% 0%, #191428 0%, #0E0E13 55%)
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.0,
            stops: [0, 0.55],
            colors: [Color(0xFF191428), AppColors.bg],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppMark(
                    size: 76,
                    radius: 22,
                    shadow: BoxShadow(
                      color: Color(0xA67C5CFF), // rgba(124,92,255,.65)
                      offset: Offset(0, 18),
                      blurRadius: 44,
                      spreadRadius: -12,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    'My Comic',
                    style: AppTypography.jakarta(
                      size: 29,
                      weight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 250),
                    child: Text(
                      'Baca komik dari sumber pilihanmu dan sinkronkan '
                      'koleksi antar-device.',
                      textAlign: TextAlign.center,
                      style: AppTypography.jakarta(
                        size: 14.5,
                        weight: FontWeight.w500,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 46),
              child: Column(
                children: [
                  _GoogleButton(onTap: _login, busy: _signingIn),
                  const SizedBox(height: 16),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                            text: 'Dengan lanjut kamu setuju pada\n'),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: AppTypography.jakarta(
                            size: 12,
                            weight: FontWeight.w600,
                            color: AppColors.accentText,
                          ),
                        ),
                        const TextSpan(text: '  ·  '),
                        TextSpan(
                          text: 'Terms of Service',
                          style: AppTypography.jakarta(
                            size: 12,
                            weight: FontWeight.w600,
                            color: AppColors.accentText,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: AppTypography.jakarta(
                      size: 12,
                      weight: FontWeight.w400,
                      height: 1.6,
                      color: AppColors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onTap, required this.busy});

  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40FFFFFF), // rgba(255,255,255,.25)
            offset: Offset(0, 12),
            blurRadius: 30,
            spreadRadius: -10,
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.string(_googleLogoSvg, width: 21, height: 21),
                const SizedBox(width: 12),
                Text(
                  'Continue with Google',
                  style: AppTypography.jakarta(
                    size: 16,
                    weight: FontWeight.w700,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
