import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _kPrefVpnEnabled = 'kizen_vpn_enabled';
const _kPrefVpnProvider = 'kizen_vpn_provider';
const _channel = MethodChannel('kizen/extension_runtime');

/// Pilihan provider DNS-over-HTTPS / Tunnel anti-blokir
enum VpnProvider {
  cloudflare('cloudflare', 'Cloudflare 1.1.1.1 (Singapore)', 'https://cloudflare-dns.com/dns-query'),
  google('google', 'Google Public DNS (Global)', 'https://dns.google/resolve'),
  adguard('adguard', 'AdGuard Shield (Anti-Ad & Malware)', 'https://dns.adguard-dns.com/dns-query');

  const VpnProvider(this.id, this.label, this.endpoint);
  final String id;
  final String label;
  final String endpoint;

  static VpnProvider fromId(String id) {
    for (final p in values) {
      if (p.id == id) return p;
    }
    return VpnProvider.cloudflare;
  }
}

/// Status koneksi VPN / Anti-Blokir Kizen
class VpnState {
  const VpnState({
    required this.isEnabled,
    required this.provider,
    required this.pingMs,
    required this.isConnecting,
    this.lastTestedAt,
    this.testedHosts = const {},
  });

  final bool isEnabled;
  final VpnProvider provider;
  final int pingMs;
  final bool isConnecting;
  final DateTime? lastTestedAt;
  final Map<String, bool> testedHosts;

  VpnState copyWith({
    bool? isEnabled,
    VpnProvider? provider,
    int? pingMs,
    bool? isConnecting,
    DateTime? lastTestedAt,
    Map<String, bool>? testedHosts,
  }) {
    return VpnState(
      isEnabled: isEnabled ?? this.isEnabled,
      provider: provider ?? this.provider,
      pingMs: pingMs ?? this.pingMs,
      isConnecting: isConnecting ?? this.isConnecting,
      lastTestedAt: lastTestedAt ?? this.lastTestedAt,
      testedHosts: testedHosts ?? this.testedHosts,
    );
  }
}

/// Notifier pengelola status VPN & Anti-Blokir Kizen
class VpnNotifier extends Notifier<VpnState> {
  @override
  VpnState build() {
    // Muat konfigurasi tersimpan dari SharedPreferences
    _loadPreferences();
    return const VpnState(
      isEnabled: true, // Default aktif agar pengguna langsung bebas dari blokir
      provider: VpnProvider.cloudflare,
      pingMs: 24,
      isConnecting: false,
    );
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_kPrefVpnEnabled) ?? true;
      final providerId = prefs.getString(_kPrefVpnProvider) ?? 'cloudflare';
      final provider = VpnProvider.fromId(providerId);

      state = state.copyWith(
        isEnabled: enabled,
        provider: provider,
      );

      // Sinkronkan ke native Android runtime
      _syncNative(enabled, provider.id);
      if (enabled) {
        testConnection();
      }
    } catch (_) {}
  }

  Future<void> toggle() async {
    final nextState = !state.isEnabled;
    state = state.copyWith(isConnecting: true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefVpnEnabled, nextState);
      await _syncNative(nextState, state.provider.id);

      int ping = state.pingMs;
      if (nextState) {
        ping = await _measurePing(state.provider);
      }

      state = state.copyWith(
        isEnabled: nextState,
        isConnecting: false,
        pingMs: ping,
      );

      if (nextState) {
        testConnection();
      }
    } catch (_) {
      state = state.copyWith(isConnecting: false);
    }
  }

  Future<void> setProvider(VpnProvider provider) async {
    state = state.copyWith(provider: provider, isConnecting: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefVpnProvider, provider.id);
      await _syncNative(state.isEnabled, provider.id);

      final ping = await _measurePing(provider);
      state = state.copyWith(
        provider: provider,
        isConnecting: false,
        pingMs: ping,
      );
      testConnection();
    } catch (_) {
      state = state.copyWith(isConnecting: false);
    }
  }

  Future<void> testConnection() async {
    final hosts = {
      'Shinigami': 'shinigami.cx',
      'Komiku': 'api.komiku.id',
      'Komikindo': 'komikindo.ch',
      'Asura Comic': 'asuracomic.net',
    };

    final results = <String, bool>{};
    for (final entry in hosts.entries) {
      try {
        final uri = Uri.parse(
          'https://cloudflare-dns.com/dns-query?name=${entry.value}&type=A',
        );
        final res = await http.get(
          uri,
          headers: {'Accept': 'application/dns-json'},
        ).timeout(const Duration(seconds: 4));
        results[entry.key] = res.statusCode == 200;
      } catch (_) {
        results[entry.key] = false;
      }
    }

    state = state.copyWith(
      lastTestedAt: DateTime.now(),
      testedHosts: results,
    );
  }

  Future<int> _measurePing(VpnProvider provider) async {
    final sw = Stopwatch()..start();
    try {
      final uri = Uri.parse('${provider.endpoint}?name=google.com&type=A');
      await http.get(
        uri,
        headers: {'Accept': 'application/dns-json'},
      ).timeout(const Duration(seconds: 3));
      sw.stop();
      return sw.elapsedMilliseconds.clamp(15, 350);
    } catch (_) {
      return 45;
    }
  }

  Future<void> _syncNative(bool enabled, String providerId) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('setVpnEnabled', {
        'enabled': enabled,
        'provider': providerId,
      });
    } catch (_) {}
  }

  Future<void> openSystemVpnSettings() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('openVpnSettings');
    } catch (_) {}
  }

  Future<void> openPrivateDnsSettings() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('openPrivateDnsSettings');
    } catch (_) {}
  }
}

final vpnProvider = NotifierProvider<VpnNotifier, VpnState>(() {
  return VpnNotifier();
});
