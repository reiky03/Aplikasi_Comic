import 'package:flutter/material.dart';

/// Token warna "Kizen" — dark-first, satu-satunya tema.
/// Palet: navy gelap + biru ombak + aksen merah seal (brand Kizen).
abstract final class AppColors {
  /// Background layar/app.
  static const Color bg = Color(0xFF05070A);

  /// Cards, list rows, input fields, bottom sheets, bottom nav.
  static const Color surface = Color(0xFF101B2D);

  /// Icon buttons di header (search/filter).
  static const Color surfaceAlt = Color(0xFF16263D);

  /// Tag pills, track background progress bar.
  static const Color surfaceSunken = Color(0xFF1A2C46);

  /// Lingkaran background ikon empty-state.
  static const Color surfaceEmptyIcon = Color(0xFF0E1826);

  /// Border default card/row — rgba(255,255,255,0.06).
  static const Color border = Color(0x0FFFFFFF);

  /// Border icon-button, divider — rgba(255,255,255,0.1).
  static const Color borderStrong = Color(0x1AFFFFFF);

  /// Primary: tombol utama, pill tab aktif, FAB, nav icon aktif,
  /// progress bar, background teks highlight.
  static const Color accent = Color(0xFF1E88C8);

  /// Links, label aktif, copy highlight, teks nav aktif ("highlight aktif").
  static const Color accentText = Color(0xFF7EC8E3);

  static const Color textPrimary = Color(0xFFF8F6F0);
  static const Color textSecondary = Color(0xFFB7C4CE);
  static const Color textMuted = Color(0xFF90A0AF);

  /// Least-emphasis: nav inaktif, hint disabled.
  static const Color textFaint = Color(0xFF62748A);

  /// Footnotes.
  static const Color textFaintest = Color(0xFF3F4F63);

  /// Atribusi sumber di bawah judul.
  static const Color textFaintestAlt = Color(0xFF6E8296);

  /// Status "Normal"/"Session aktif", banner sukses, state download selesai.
  static const Color success = Color(0xFF34D399);

  /// Status "Membutuhkan WebView"/"Terbatas".
  static const Color warning = Color(0xFFF2B44C);
  static const Color warningAlt = Color(0xFFE0913A);

  /// Status "Gagal diakses", tombol/teks destruktif, sign-out ("seal red").
  static const Color danger = Color(0xFFD6422B);
  static const Color dangerAlt = Color(0xFFE85A42);

  /// Badge notifikasi/unread/"baru" — sama dengan [danger] (seal merah),
  /// dipisah namanya karena beda konteks pemakaian (badge, bukan destruktif).
  static const Color badge = danger;

  /// Tint background tombol destruktif — rgba(214,66,43,0.08–0.14).
  static const Color dangerBg = Color(0x14D6422B); // alpha 0.08
  static const Color dangerBgStrong = Color(0x24D6422B); // alpha 0.14

  /// Drag handle bottom sheet — rgba(255,255,255,0.2).
  static const Color sheetDragHandle = Color(0x33FFFFFF);

  // --- Token komponen dari 15_shared_components.md / prototipe ---

  /// Scrim bottom sheet — rgba(0,0,0,0.55).
  static const Color scrim = Color(0x8C000000);

  /// Border atas bottom sheet — rgba(255,255,255,0.08).
  static const Color sheetTopBorder = Color(0x14FFFFFF);

  /// Divider antar row opsi di sheet — rgba(255,255,255,0.05).
  static const Color sheetRowDivider = Color(0x0DFFFFFF);

  /// Background toast.
  static const Color toastBg = Color(0xFF1D2F49);

  /// Highlight hover/pressed row menu & bg segment inaktif.
  static const Color rowHighlight = Color(0xFF18283F);

  /// Warna ikon di row menu konteks.
  static const Color menuIcon = Color(0xFFC7D2DC);

  /// Stroke ikon empty-state.
  static const Color emptyIcon = Color(0xFF3C5068);

  /// Track pill switch posisi off (juga bg tombol disabled "Buat").
  static const Color switchTrackOff = Color(0xFF22354F);

  /// Segment aktif — rgba(30,136,200,0.16) bg, rgba(30,136,200,0.5) border.
  static const Color segmentActiveBg = Color(0x291E88C8);
  static const Color segmentActiveBorder = Color(0x801E88C8);

  /// Border/bg affordance "Buat koleksi baru" (dashed) —
  /// rgba(30,136,200,0.4) / rgba(30,136,200,0.06).
  static const Color accentBorderFaint = Color(0x661E88C8);
  static const Color accentBgFaint = Color(0x0F1E88C8);

  /// Border tombol hapus koleksi — rgba(214,66,43,0.25).
  static const Color dangerBorder = Color(0x40D6422B);

  /// Shadow FAB — rgba(30,136,200,0.7).
  static const Color fabShadow = Color(0xB31E88C8);

  /// Gradient aksen: FAB, avatar fallback — "ombak" biru-ke-navy.
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment(-0.5, -0.87),
    end: Alignment(0.5, 0.87),
    colors: [Color(0xFF3AA8DE), Color(0xFF123A5C)],
  );

  /// Background wash khusus layar Splash & Login — radial navy gelap.
  static const RadialGradient bgGradientSplash = RadialGradient(
    center: Alignment.topCenter,
    radius: 1.2,
    colors: [Color(0xFF0D1C2E), Color(0xFF05070A)],
  );

  // --- Light mode (opsional, belum diaktifkan — lihat catatan di bawah) ---
  //
  // Palet terang disiapkan sebagai referensi untuk saat toggle Tema di
  // Setelan benar-benar diimplementasikan (sekarang masih dekoratif/TODO,
  // sesuai keputusan desain awal "dark-first"). Belum dipakai di ThemeData.
  static const Color lightBg = Color(0xFFF8F6F0);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF07111F);
  static const Color lightAccent = Color(0xFF1E88C8);
  static const Color lightAccentAlt = Color(0xFFD6422B);
}
