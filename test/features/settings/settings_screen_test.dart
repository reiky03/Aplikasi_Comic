import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aplikasi_komik/features/settings/about_screen.dart';
import 'package:aplikasi_komik/features/settings/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'kizen_vpn_enabled': false,
    });
  });

  testWidgets('SettingsScreen menampilkan versi aplikasi sinkron dengan kAppVersion',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SettingsScreen(),
          ),
        ),
      ),
    );

    // Scroll sampai ke bawah untuk menemukan teks versi
    final versionFinder = find.text('Kizen v$kAppVersion');
    await tester.scrollUntilVisible(versionFinder, 300);

    expect(versionFinder, findsOneWidget);

    // Pastikan tidak ada string versi lama yang salah
    expect(find.text('Kizen v1.2.4'), findsNothing);
    expect(find.text('Kizen v1.2.5'), findsNothing);

    // Mengetuk versi membuka AboutScreen
    await tester.tap(versionFinder);
    await tester.pumpAndSettle();

    expect(find.byType(AboutScreen), findsOneWidget);
    expect(find.text('v$kAppVersion (build $kAppBuild)'), findsOneWidget);
  });
}
