import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aplikasi_komik/data/vpn_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('VpnState default bernilai aktif dengan Cloudflare DoH', () {
    const state = VpnState(
      isEnabled: true,
      provider: VpnProvider.cloudflare,
      pingMs: 24,
      isConnecting: false,
    );
    expect(state.isEnabled, isTrue);
    expect(state.provider, VpnProvider.cloudflare);
    expect(state.isConnecting, isFalse);
    expect(state.pingMs, 24);
  });

  test('VpnNotifier dapat mengubah status toggle dan provider', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Initial
    final initial = container.read(vpnProvider);
    expect(initial.isEnabled, isTrue);

    // Toggle off
    await container.read(vpnProvider.notifier).toggle();
    expect(container.read(vpnProvider).isEnabled, isFalse);

    // Toggle on kembali
    await container.read(vpnProvider.notifier).toggle();
    expect(container.read(vpnProvider).isEnabled, isTrue);

    // Ganti ke Google DNS
    await container.read(vpnProvider.notifier).setProvider(VpnProvider.google);
    expect(container.read(vpnProvider).provider, VpnProvider.google);

    // Ganti ke AdGuard DNS
    await container.read(vpnProvider.notifier).setProvider(VpnProvider.adguard);
    expect(container.read(vpnProvider).provider, VpnProvider.adguard);
  });
}
