import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_typography.dart';

/// Isi visual cover: gambar asli (kalau [coverUrl] ada & berhasil dimuat)
/// atau inisial besar transparan di atas gradient placeholder — dipasang
/// sebagai children pertama Stack cover manapun (grid, hero, dll).
///
/// Di Android/iOS menggunakan [CachedNetworkImage] agar file cover tersimpan di disk
/// cache dan tidak perlu mengunduh ulang setiap kali aplikasi dibuka atau discroll.
Widget comicCoverContent({
  required String? coverUrl,
  required String initial,
  Map<String, String> headers = const {},
  double fontSize = 52,
  // Ukuran target decode (piksel fisik) — tanpa ini Flutter decode cover
  // di resolusi ASLI-nya biar pun tampil kecil di grid, boros GPU/memory
  // pas banyak kartu ke-render sekaligus saat scroll. Null = biarkan
  // decode native (dipakai buat tampilan besar seperti hero cover Detail).
  int? cacheWidth,
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

  if (kIsWeb) {
    return Image.network(
      coverUrl,
      fit: BoxFit.cover,
      headers: headers.isEmpty ? null : headers,
      cacheWidth: cacheWidth,
      errorBuilder: (_, _, _) => placeholder,
    );
  }

  return CachedNetworkImage(
    imageUrl: coverUrl,
    fit: BoxFit.cover,
    httpHeaders: headers.isEmpty ? null : headers,
    memCacheWidth: cacheWidth,
    fadeInDuration: const Duration(milliseconds: 150),
    fadeOutDuration: const Duration(milliseconds: 150),
    placeholder: (_, _) => placeholder,
    errorWidget: (_, _, _) => placeholder,
  );
}
