import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aplikasi_komik/core/theme/app_theme.dart';
import 'package:aplikasi_komik/features/history/history_screen.dart';

void main() {
  testWidgets('tekan lama bisa menghapus satu riwayat setelah konfirmasi', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(body: HistoryScreen()),
        ),
      ),
    );

    expect(find.text('Neon Samurai'), findsOneWidget);
    expect(find.text('Echoes of the Void'), findsOneWidget);

    await tester.longPress(find.text('Neon Samurai'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus dari History'), findsOneWidget);

    await tester.tap(find.text('Hapus dari History'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus dari History?'), findsOneWidget);

    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Neon Samurai'), findsNothing);
    expect(find.text('Echoes of the Void'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2500));
  });

  testWidgets('tombol bersihkan riwayat meminta konfirmasi dialog sebelum menghapus', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(body: HistoryScreen()),
        ),
      ),
    );

    expect(find.text('Echoes of the Void'), findsOneWidget);

    // Ketuk tombol Bersihkan di header
    final clearBtn = find.text('Bersihkan');
    expect(clearBtn, findsOneWidget);
    await tester.tap(clearBtn);
    await tester.pumpAndSettle();

    // Dialog konfirmasi harus muncul
    expect(find.text('Bersihkan Riwayat?'), findsOneWidget);
    expect(
      find.text(
        'Semua riwayat baca komik akan dihapus. Komik di Library dan '
        'progres chapter tidak ikut terhapus.',
      ),
      findsOneWidget,
    );

    // Tekan konfirmasi 'Bersihkan' di dialog
    await tester.tap(find.widgetWithText(InkWell, 'Bersihkan').last);
    await tester.pumpAndSettle();

    // Riwayat sekarang kosong
    expect(find.text('Belum ada riwayat baca'), findsOneWidget);
    expect(find.text('Echoes of the Void'), findsNothing);
    await tester.pump(const Duration(milliseconds: 2500));
  });
}
