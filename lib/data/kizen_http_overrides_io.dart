import 'dart:async';
import 'dart:io';

import 'doh_resolver.dart';
import 'vpn_state.dart';

/// Overrides default [HttpClient] in Dart IO to route connections through
/// DNS-over-HTTPS (DoH) and direct IP sockets with TLS SNI when VPN is enabled.
class KizenHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.connectionFactory = (
      Uri uri,
      String? proxyHost,
      int? proxyPort,
    ) async {
      final host = uri.host;
      if (!VpnNotifier.currentVpnEnabled || host.isEmpty || proxyHost != null) {
        return Socket.startConnect(uri.host, uri.port);
      }

      // Hindari loop DoH jika sedang me-resolve ke endpoint DoH itu sendiri
      if (host.contains('dns') || host.contains('cloudflare') || host.contains('google')) {
        return Socket.startConnect(uri.host, uri.port);
      }

      final provider = VpnNotifier.currentProviderId;
      final ip = await DohResolver.resolveHost(host, provider: provider);
      if (ip == null || ip.isEmpty) {
        return Socket.startConnect(uri.host, uri.port);
      }

      try {
        final rawSocket = await Socket.connect(
          ip,
          uri.port,
          timeout: const Duration(seconds: 10),
        );
        if (uri.scheme == 'https' || uri.port == 443) {
          final secSocket = await SecureSocket.secure(rawSocket, host: host);
          return ConnectionTask.fromSocket(
            Future.value(secSocket),
            () => rawSocket.destroy(),
          );
        }
        return ConnectionTask.fromSocket(
          Future.value(rawSocket),
          () => rawSocket.destroy(),
        );
      } catch (_) {
        // Fallback ke koneksi biasa jika koneksi DoH gagal
        return Socket.startConnect(uri.host, uri.port);
      }
    };
    return client;
  }
}

void installKizenHttpOverrides() {
  HttpOverrides.global = KizenHttpOverrides();
}
