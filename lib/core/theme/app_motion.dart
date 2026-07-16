import 'package:flutter/material.dart';

/// Durasi & curve animasi "Kizen".
/// Sumber kebenaran: design_handoff_my_comic/01_design_system.md
abstract final class AppMotion {
  /// Transisi antar layar: fade + slide naik tipis (~250–300ms, ease).
  static const Duration screenTransition = Duration(milliseconds: 280);
  static const Curve screenTransitionCurve = Curves.ease;

  /// Bottom sheet masuk: slide dari bawah, cubic-bezier(0.2, 0.8, 0.2, 1).
  static const Duration sheetEnter = Duration(milliseconds: 280);
  static const Curve sheetCurve = Cubic(0.2, 0.8, 0.2, 1);

  /// Spinner: ring berputar ~0.7–0.8s linear, stroke 2–3px,
  /// track pada 25–30% opasitas warna spinner.
  static const Duration spinnerPeriod = Duration(milliseconds: 750);
  static const double spinnerStrokeWidth = 2.5;
  static const double spinnerTrackOpacity = 0.28;

  /// Toast: fade/slide dari bawah, auto-dismiss ~2.4s.
  static const Duration toastVisible = Duration(milliseconds: 2400);
}

/// Transisi layar default: fade + slide naik tipis, sesuai prototipe.
class FadeSlideUpPageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeSlideUpPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: AppMotion.screenTransitionCurve,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
