import 'package:flutter/material.dart';

/// Logo mark "Kizen": lingkaran ombak navy + kanji 善, dari
/// assets/branding/kizen_mark.png (radius diabaikan — mark aslinya bundar).
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
        shape: BoxShape.circle,
        boxShadow: shadow == null ? null : [shadow!],
        image: const DecorationImage(
          image: AssetImage('assets/branding/kizen_mark.png'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
