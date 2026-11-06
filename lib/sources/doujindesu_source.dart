import 'dart:convert';
import 'package:http/http.dart' as http;

import '../data/extension_runtime.dart';
import '../data/kizen_http_client.dart';
import '../data/source_session_store.dart';
import 'manga_source.dart';

/// Sumber bawaan untuk Doujindesu (https://doujin.desu.xxx).
///
/// Doujindesu adalah React Single Page App (SPA) dengan payload terenkripsi
/// XOR bergulir per jam (_enc_resp_). Parser ini membaca langsung API JSON
/// resmi Doujindesu sehingga bekerja 100% cepat dan stabil, baik ekstensi APK
/// terpasang maupun tidak, di Android, Web, dan desktop.
class DoujindesuSource implements MangaSource {
  DoujindesuSource({
    this.name = 'Doujindesu',
    this.baseUrl = 'https://doujin.desu.xxx',
    http.Client? client,
  }) : _client = client ?? createKizenHttpClient();

  @override
  final String name;

  @override
  final String baseUrl;

  final http.Client _client;

  static const _salt =
      'doujindesu-scrapers-cannot-read-this-super-secret-salt-2026-v2';

  Map<String, String> get _headers {
    final session = SourceSessionStore.headersFor(baseUrl);
    return {
      'Accept': 'application/json, text/plain, */*',
      'Referer': '$baseUrl/',
      'User-Agent': session['User-Agent'] ??
          'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
      if (session.containsKey('Cookie')) 'Cookie': session['Cookie']!,
    };
  }

  static int _toSigned32(int x) {
    var y = x & 0xFFFFFFFF;
    if (y >= 0x80000000) {
      y -= 0x100000000;
    }
    return y;
  }

  static String _wH(int e) {
    final t = '${_salt}_$e';
    var a = 0;
    for (var i = 0; i < t.length; i++) {
      a = (a << 5) - a + t.codeUnitAt(i);
      a = _toSigned32(a);
    }
    var l = a != 0 ? a.abs() : 123456789;
    final buffer = StringBuffer();
    for (var i = 0; i < 32; i++) {
      l = (l * 1664525 + 1013904223) % 4294967296;
      buffer.writeCharCode(33 + (l % 93));
    }
    return buffer.toString();
  }

  /// Dekripsi payload hex XOR Doujindesu
  static String? decryptPayload(String raw) {
    var cleanJson = raw.trim();
    if (cleanJson.contains('_enc_resp_')) {
      try {
        final parsed = jsonDecode(cleanJson) as Map<String, dynamic>;
        cleanJson = parsed['_enc_resp_'] as String? ?? cleanJson;
      } catch (_) {}
    }

    final cleanHex = cleanJson.trim();
    final bytes = <int>[];
    for (var i = 0; i < cleanHex.length; i += 2) {
      if (i + 2 > cleanHex.length) break;
      final b = int.tryParse(cleanHex.substring(i, i + 2), radix: 16);
      if (b != null) bytes.add(b);
    }
    if (bytes.isEmpty) return null;

    final now = DateTime.now().millisecondsSinceEpoch;
    final t = (now / 3600000).floor();
    final keys = [_wH(t), _wH(t - 1), _wH(t + 1)];

    for (final key in keys) {
      try {
        var d = 42;
        final keyLen = key.length;
        final decodedBytes = <int>[];
        for (var idx = 0; idx < bytes.length; idx++) {
          final keyChar = key.codeUnitAt(idx % keyLen);
          final k = bytes[idx] ^ keyChar ^ (idx * 13) ^ d;
          decodedBytes.add(k & 0xFF);
          d = (d + bytes[idx]) % 256;
        }
        final decoded = utf8.decode(decodedBytes, allowMalformed: true);
        final unquoted = Uri.decodeComponent(decoded);
        if ((unquoted.startsWith('[') && unquoted.endsWith(']')) ||
            (unquoted.startsWith('{') && unquoted.endsWith('}'))) {
          return unquoted;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<dynamic> _fetchApi(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    http.Response? response;
    try {
      response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
    } catch (_) {}

    final isBlocked = response == null ||
        response.statusCode == 403 ||
        response.body.contains('Just a moment...') ||
        response.body.contains('challenges.cloudflare.com');

    if (isBlocked) {
      try {
        final session =
            await const ExtensionRuntimeBridge().readWebViewSession(baseUrl);
        final cookie = session.cookie ?? '';
        if (cookie.isNotEmpty) {
          await SourceSessionStore.save(
            url: baseUrl,
            cookie: cookie,
            userAgent: session.userAgent,
          );
          response = await _client
              .get(uri, headers: _headers)
              .timeout(const Duration(seconds: 15));
        }
      } catch (_) {}
    }

    if (response == null) {
      throw MangaSourceWebViewException(
        url: '$baseUrl$path',
        message:
            'Gagal menghubungi $name. Aktifkan VPN Kizen atau buka lewat WebView.',
      );
    }

    if (response.statusCode == 403 ||
        response.body.contains('Just a moment...') ||
        response.body.contains('challenges.cloudflare.com')) {
      throw MangaSourceWebViewException(
        url: '$baseUrl$path',
        message:
            'Cloudflare Turnstile terdeteksi (HTTP 403). Selesaikan verifikasi sekali di WebView untuk membuka akses.',
      );
    }

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode} saat memanggil $path');
    }
    final decrypted = decryptPayload(response.body);
    if (decrypted == null) {
      throw Exception('Gagal mendekripsi payload Doujindesu dari $path');
    }
    return jsonDecode(decrypted);
  }

  String _cleanSlug(String rawUrl) {
    var path = rawUrl.trim();
    if (path.startsWith('http://') || path.startsWith('https://')) {
      path = Uri.parse(path).path;
    }
    path = path.replaceAll(RegExp(r'^/manga/'), '');
    path = path.replaceAll(RegExp(r'^/api/manga/'), '');
    path = path.replaceAll(RegExp(r'/$'), '');
    return path;
  }

  String _cleanChapterId(String rawUrl) {
    var path = rawUrl.trim();
    if (path.startsWith('http://') || path.startsWith('https://')) {
      path = Uri.parse(path).path;
    }
    path = path.replaceAll(RegExp(r'^/chapter/'), '');
    path = path.replaceAll(RegExp(r'^/api/chapters/'), '');
    path = path.replaceAll(RegExp(r'/$'), '');
    return path;
  }

  @override
  Future<SourceMangaPage> fetchPopular(int page) async {
    final offset = (page - 1) * 24;
    final json = await _fetchApi('/api/manga?limit=24&offset=$offset&sort=rating');
    final items = (json as List).cast<Map<String, dynamic>>();
    final mangas = items.map((item) {
      final slug = item['slug'] as String? ?? '';
      return SourceManga(
        title: item['title'] as String? ?? '',
        url: '/manga/$slug/',
        thumbnailUrl: item['cover_url'] as String?,
      );
    }).toList();
    return SourceMangaPage(mangas: mangas, hasNextPage: mangas.length >= 24);
  }

  @override
  Future<SourceMangaPage> fetchLatest(int page) async {
    final offset = (page - 1) * 24;
    final json = await _fetchApi(
      '/api/manga?limit=24&offset=$offset&sort=latest_chapter',
    );
    final items = (json as List).cast<Map<String, dynamic>>();
    final mangas = items.map((item) {
      final slug = item['slug'] as String? ?? '';
      return SourceManga(
        title: item['title'] as String? ?? '',
        url: '/manga/$slug/',
        thumbnailUrl: item['cover_url'] as String?,
      );
    }).toList();
    return SourceMangaPage(mangas: mangas, hasNextPage: mangas.length >= 24);
  }

  @override
  Future<SourceMangaPage> fetchSearch(String query, int page) async {
    final offset = (page - 1) * 24;
    final encoded = Uri.encodeComponent(query);
    final json = await _fetchApi('/api/manga?limit=24&offset=$offset&search=$encoded');
    final items = (json as List).cast<Map<String, dynamic>>();
    final mangas = items.map((item) {
      final slug = item['slug'] as String? ?? '';
      return SourceManga(
        title: item['title'] as String? ?? '',
        url: '/manga/$slug/',
        thumbnailUrl: item['cover_url'] as String?,
      );
    }).toList();
    return SourceMangaPage(mangas: mangas, hasNextPage: mangas.length >= 24);
  }

  @override
  Future<SourceMangaDetails> fetchMangaDetails(String mangaUrl) async {
    final slug = _cleanSlug(mangaUrl);
    final json = await _fetchApi('/api/manga/$slug') as Map<String, dynamic>;

    final genres = <String>[];
    final rawGenres = json['manga_genres'] as List?;
    if (rawGenres != null) {
      for (final g in rawGenres) {
        if (g is Map && g['genre'] is Map) {
          final name = g['genre']['name'] as String?;
          if (name != null && name.isNotEmpty) genres.add(name);
        }
      }
    }

    final rawStatus = (json['status'] as String? ?? '').toLowerCase();
    final status = rawStatus == 'completed'
        ? SourceMangaStatus.completed
        : rawStatus == 'ongoing' || rawStatus == 'publishing'
            ? SourceMangaStatus.ongoing
            : SourceMangaStatus.unknown;

    return SourceMangaDetails(
      description: json['description'] as String?,
      author: json['author'] as String?,
      artist: json['artist'] as String?,
      genres: genres,
      status: status,
      thumbnailUrl: json['cover_url'] as String?,
    );
  }

  @override
  Future<List<SourceChapter>> fetchChapterList(String mangaUrl) async {
    final slug = _cleanSlug(mangaUrl);
    final json = await _fetchApi('/api/manga/$slug') as Map<String, dynamic>;
    final rawChapters = json['chapters'] as List?;
    if (rawChapters == null || rawChapters.isEmpty) return const [];

    return rawChapters.map((ch) {
      final map = ch as Map<String, dynamic>;
      final chId = map['id'] as String? ?? '';
      final title = map['title'] as String? ?? 'Chapter ${map['chapter_number'] ?? ''}';
      final dateStr = map['created_at'] as String?;
      DateTime? dateUpload;
      if (dateStr != null) {
        dateUpload = DateTime.tryParse(dateStr);
      }
      return SourceChapter(
        url: '/chapter/$chId',
        name: title,
        dateUpload: dateUpload,
      );
    }).toList();
  }

  @override
  Future<List<SourcePage>> fetchPageList(String chapterUrl) async {
    final chapterId = _cleanChapterId(chapterUrl);
    final json = await _fetchApi('/api/chapters/$chapterId') as Map<String, dynamic>;
    final contentUrls = json['content_urls'] as List?;
    if (contentUrls == null || contentUrls.isEmpty) return const [];

    final imageHeaders = {
      'Referer': '$baseUrl/',
      'User-Agent': _headers['User-Agent']!,
    };

    return contentUrls.asMap().entries.map((entry) {
      final url = entry.value as String;
      return SourcePage(
        index: entry.key,
        imageUrl: url,
        headers: imageHeaders,
      );
    }).toList();
  }
}
