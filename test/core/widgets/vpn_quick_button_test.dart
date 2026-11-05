import 'package:aplikasi_komik/core/widgets/vpn_quick_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'kizen_vpn_enabled': true,
      'kizen_vpn_provider': 'cloudflare',
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('kizen/extension_runtime'),
            (MethodCall methodCall) async {
      if (methodCall.method == 'setVpnEnabled') {
        return true;
      }
      return null;
    });
  });

  testWidgets('KizenVpnQuickButton renders and toggles VPN state', (tester) async {
    bool? toggledResult;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: KizenVpnQuickButton(
                compact: false,
                onToggled: (enabled) {
                  toggledResult = enabled;
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Default state: isEnabled == true (VPN ON)
    expect(find.text('VPN ON'), findsOneWidget);
    expect(find.byIcon(LucideIcons.shieldCheck), findsOneWidget);

    // Tap to toggle
    await tester.tap(find.byType(KizenVpnQuickButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Sekarang menjadi VPN OFF
    expect(toggledResult, isFalse);
    expect(find.text('VPN OFF'), findsOneWidget);
    expect(find.byIcon(LucideIcons.shieldAlert), findsOneWidget);

    // Habiskan timer AppToast (2400ms) agar invariant test bersih
    await tester.pump(const Duration(milliseconds: 3000));
  });
}
