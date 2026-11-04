import 'dart:convert';
import 'package:http/http.dart' as http;

/// Resolver DNS-over-HTTPS (DoH) untuk membypass pemblokiran DNS ISP di Indonesia.
class DohResolver {
  static final Map<String, String> _cache = {};

  /// Daftar endpoint DoH publik terpercaya
  static String _getEndpoint(String provider, String host) {
    switch (provider) {
      case 'hongkong':
        return 'https://doh.dns.sb/dns-query?name=$host&type=A';
      case 'google':
        return 'https://dns.google/resolve?name=$host&type=A';
      case 'adguard':
        return 'https://dns.adguard-dns.com/dns-query?name=$host&type=A';
      case 'cloudflare':
      default:
        return 'https://cloudflare-dns.com/dns-query?name=$host&type=A';
    }
  }

  /// Resolve hostname ke IP address publik via Cloudflare / Hong Kong / Google DoH.
  static Future<String?> resolveHost(
    String host, {
    String provider = 'cloudflare',
  }) async {
    final cleanHost = host.trim().toLowerCase();
    if (RegExp(r'^[0-9.]+$').hasMatch(cleanHost) || cleanHost.contains(':')) {
      return cleanHost;
    }

    if (_cache.containsKey(cleanHost)) {
      return _cache[cleanHost];
    }

    // Urutan endpoint: coba provider pilihan dulu, lalu fallback ke Cloudflare & Google
    final endpoints = <String>[
      _getEndpoint(provider, cleanHost),
      if (provider != 'cloudflare') _getEndpoint('cloudflare', cleanHost),
      if (provider != 'google') _getEndpoint('google', cleanHost),
    ];

    for (final endpoint in endpoints) {
      try {
        final res = await http.get(
          Uri.parse(endpoint),
          headers: {'Accept': 'application/dns-json'},
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final answers = data['Answer'] as List<dynamic>?;
          if (answers != null && answers.isNotEmpty) {
            for (final a in answers) {
              if (a is Map<String, dynamic> && a['type'] == 1) {
                final ip = a['data'] as String?;
                if (ip != null &&
                    ip.isNotEmpty &&
                    !ip.startsWith('180.250.') &&
                    !ip.startsWith('36.86.') &&
                    !ip.startsWith('118.98.') &&
                    !ip.startsWith('103.236.') &&
                    ip != '127.0.0.1' &&
                    ip != '0.0.0.0') {
                  // Pastikan bukan IP redirect blokir ISP / Nawala
                  _cache[cleanHost] = ip;
                  return ip;
                }
              }
            }
          }
        }
      } catch (_) {
        // Lanjutkan ke endpoint berikutnya
      }
    }

    return null;
  }

  static void clearCache() {
    _cache.clear();
  }
}
