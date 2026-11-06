import 'package:aplikasi_komik/features/browse/add_source_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestWidget() {
    return const ProviderScope(
      child: MaterialApp(
        home: AddSourceScreen(),
      ),
    );
  }

  testWidgets('Simpan Sumber tanpa mengisi URL memunculkan toast URL kosong',
      (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pump();

    // Tap Simpan Sumber
    await tester.tap(find.text('Simpan Sumber'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('Masukkan URL website komik terlebih dahulu'),
      findsOneWidget,
    );

    // Habiskan timer toast agar invariant test bersih
    await tester.pump(const Duration(milliseconds: 3000));
  });

  testWidgets(
      'Simpan Sumber setelah isi URL tanpa tekan Test Sumber memunculkan toast peringatan',
      (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pump();

    // Isi URL saja
    await tester.enterText(find.byType(TextField).at(1), 'https://example.com');
    await tester.pump();

    // Muncul petunjuk di bawah URL
    expect(
      find.text('Tekan "Test Sumber" di bawah untuk menguji URL ini'),
      findsOneWidget,
    );

    // Tap Simpan Sumber
    await tester.tap(find.text('Simpan Sumber'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('Tekan "Test Sumber" terlebih dahulu sebelum menyimpan'),
      findsOneWidget,
    );

    // Habiskan timer toast agar invariant test bersih
    await tester.pump(const Duration(milliseconds: 3000));
  });

  testWidgets('Test Sumber saat URL kosong memunculkan toast peringatan',
      (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pump();

    // Tap Test Sumber saat URL belum diisi
    await tester.tap(find.text('Test Sumber'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('Masukkan URL website komik terlebih dahulu'),
      findsOneWidget,
    );

    // Habiskan timer toast agar invariant test bersih
    await tester.pump(const Duration(milliseconds: 3000));
  });
}
