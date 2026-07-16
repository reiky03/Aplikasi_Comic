import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aplikasi_komik/core/widgets/widgets.dart';
import 'package:aplikasi_komik/features/auth/auth_repository.dart';
import 'package:aplikasi_komik/main.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Alur onboarding: Splash → Login', (tester) async {
    // FirebaseAuthRepository butuh Firebase.initializeApp() (dipanggil di
    // main(), bukan di widget test) — pakai FakeAuthRepository di sini.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        ],
        child: const KizenApp(),
      ),
    );
    expect(find.text('Kizen'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 3600));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('Login (fake) → Sync → Library dengan bottom nav',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        ],
        child: const KizenApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 3600)); // splash
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Continue with Google'));
    await tester.pump(const Duration(milliseconds: 700)); // fake auth
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Menyinkronkan data…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1600)); // sync
    await tester.pump(const Duration(milliseconds: 400)); // transisi
    expect(find.byType(AppBottomNav), findsOneWidget);
    expect(find.text('Library'), findsWidgets);
    expect(find.text('Echoes of the Void'), findsOneWidget);
    // masih ada timer toast? tidak — selesai bersih
  });
}
