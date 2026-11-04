import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'doh_resolver.dart';
import 'vpn_state.dart';

/// HTTP Client khusus untuk sumber komik (MangaSource) yang otomatis
/// menyelesaikan hostname via DoH saat VPN Kizen aktif.
///
/// HANYA dipakai oleh parser komik sehingga 100% aman dan tidak membajak
/// Firebase Auth, Firestore gRPC, atau komponen inti Flutter lainnya.
http.Client createKizenHttpClient() {
  final rawClient = HttpClient();
  rawClient.connectionFactory = (uri, serverHost, port) async {
    final targetHost = uri.host;
    final targetPort = port ?? (uri.scheme == 'https' ? 443 : 80);

    String? targetIp;
    if (VpnNotifier.currentVpnEnabled ||
        targetHost.contains('doujin') ||
        targetHost.contains('imhentai') ||
        targetHost.contains('toongod')) {
      targetIp = await DohResolver.resolveHost(
        targetHost,
        provider: VpnNotifier.currentProviderId,
      );
    }

    final ipToConnect = targetIp ?? serverHost ?? targetHost;

    try {
      final rawSocket = await Socket.connect(
        ipToConnect,
        targetPort,
        timeout: const Duration(seconds: 12),
      );

      if (uri.scheme == 'https' || targetPort == 443) {
        final secSocket = await SecureSocket.secure(
          rawSocket,
          host: targetHost, // SNI harus hostname asli untuk verifikasi SSL valid
        );
        return ConnectionTask.fromSocket(
          Future.value(secSocket),
          () => rawSocket.destroy(),
        );
      } else {
        return ConnectionTask.fromSocket(
          Future.value(rawSocket),
          () => rawSocket.destroy(),
        );
      }
    } catch (_) {
      // Fallback ke koneksi biasa jika koneksi DoH gagal/timeout
      return Socket.startConnect(serverHost ?? targetHost, targetPort);
    }
  };

  return IOClient(rawClient);
}
