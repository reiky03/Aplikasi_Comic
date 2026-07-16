import 'package:flutter/material.dart';

import '../theme/app_typography.dart';

/// Isi visual cover: gambar asli (kalau [coverUrl] ada & berhasil dimuat)
/// atau inisial besar transparan di atas gradient placeholder — dipasang
/// sebagai children pertama Stack cover manapun (grid, hero, dll).
Widget comicCoverContent({
  required String? coverUrl,
  required String initial,
  double fontSize = 52,
}) {
  final placeholder = Center(
    child: Text(
      initial,
      style: AppTypography.jakarta(
        size: fontSize,
        weight: FontWeight.w800,
        color: Colors.white.withValues(alpha: 0.14),
      ),
    ),
  );
  if (coverUrl == null || coverUrl.isEmpty) return placeholder;
  return Image.network(
    coverUrl,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => placeholder,
  );
}
