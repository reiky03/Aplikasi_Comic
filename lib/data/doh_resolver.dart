import 'dart:convert';
import 'package:http/http.dart' as http;

/// Resolver DNS-over-HTTPS (DoH) untuk membypass pemblokiran DNS ISP di Indonesia.
class DohResolver {
  static final Map<String, String> _cache = {};

  /// Resolve hostname ke IP address publik via Cloudflare / Google DoH.
  static Future<String?> resolveHost(String host, {String provider = 'cloudflare'}) async {
    final cleanHost = host.trim().toLowerCase();
    if (RegExp(r'^[0-9.]+$').hasMatch(cleanHost)) {
      return cleanHost;
    }

    if (_cache.containsKey(cleanHost)) {
      return _cache[cleanHost];
    }

    try {
      final endpoint = provider == 'google'
          ? 'https://dns.google/resolve?name=$cleanHost&type=A'
          : 'https://cloudflare-dns.com/dns-query?name=$cleanHost&type=A';

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
              if (ip != null && ip.isNotEmpty) {
                _cache[cleanHost] = ip;
                return ip;
              }
            }
          }
        }
      }
    } catch (_) {}

    return null;
  }

  static void clearCache() {
    _cache.clear();
  }
}
