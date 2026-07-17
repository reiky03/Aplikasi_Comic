import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Cookie browser disimpan hanya di device, tidak ikut tersinkron ke Firestore.
abstract final class SourceSessionStore {
  static const _storageKey = 'source_web_sessions_v1';
  static final Map<String, _SourceSession> _sessions = {};

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      for (final entry in decoded.entries) {
        if (entry.value is! Map) continue;
        final value = Map<String, dynamic>.from(entry.value as Map);
        _sessions[entry.key.toString()] = _SourceSession(
          cookie: value['cookie'] as String? ?? '',
          userAgent: value['userAgent'] as String? ?? '',
        );
      }
    } on FormatException {
      await prefs.remove(_storageKey);
    }
  }

  static Future<void> save({
    required String url,
    String? cookie,
    String? userAgent,
  }) async {
    final host = _host(url);
    if (host == null) return;
    _sessions[host] = _SourceSession(
      cookie: cookie?.trim() ?? '',
      userAgent: userAgent?.trim() ?? '',
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode({
        for (final entry in _sessions.entries)
          entry.key: {
            'cookie': entry.value.cookie,
            'userAgent': entry.value.userAgent,
          },
      }),
    );
  }

  static Map<String, String> headersFor(String rawUrl) {
    final host = _host(rawUrl);
    if (host == null) return const {};
    _SourceSession? session;
    var bestLength = -1;
    for (final entry in _sessions.entries) {
      final domain = entry.key;
      if (host == domain ||
          host.endsWith('.$domain') ||
          domain.endsWith('.$host')) {
        if (domain.length > bestLength) {
          session = entry.value;
          bestLength = domain.length;
        }
      }
    }
    if (session == null) return const {};
    return {
      if (session.cookie.isNotEmpty) 'Cookie': session.cookie,
      if (session.userAgent.isNotEmpty) 'User-Agent': session.userAgent,
    };
  }

  static bool hasSession(String rawUrl) => headersFor(rawUrl).isNotEmpty;

  static Future<void> clearAll() async {
    _sessions.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  static String? _host(String rawUrl) {
    final value = rawUrl.trim();
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(
      value.startsWith('http://') || value.startsWith('https://')
          ? value
          : 'https://$value',
    );
    final host = uri?.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    return host == null || host.isEmpty ? null : host;
  }
}

class _SourceSession {
  const _SourceSession({required this.cookie, required this.userAgent});

  final String cookie;
  final String userAgent;
}
