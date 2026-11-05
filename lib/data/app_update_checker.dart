import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Hasil cek rilis terbaru Kizen di GitHub — lihat [checkForAppUpdate].
class AppUpdateResult {
  const AppUpdateResult({
    required this.hasUpdate,
    this.latestVersion,
    this.releaseUrl,
    this.apkUrl,
    this.apkName,
    this.apkSize,
    this.releaseTitle,
    this.releaseNotes,
    this.message,
  });

  final bool hasUpdate;

  /// Nomor versi rilis terbaru (tanpa prefix "v"), null kalau gagal/tidak ada.
  final String? latestVersion;

  /// Link halaman rilis di GitHub, dibuka kalau user pilih "Buka rilis".
  final String? releaseUrl;

  /// URL unduh langsung file APK rilis dari GitHub Releases asset.
  final String? apkUrl;

  /// Nama file APK (misal "kizen-v1.1.1.apk").
  final String? apkName;

  /// Ukuran file APK dalam bytes (misal 68729245 bytes ≈ 68.7 MB).
  final int? apkSize;

  /// Judul rilis dari GitHub (misal "Kizen v1.1.1 — ...").
  final String? releaseTitle;

  /// Catatan rilis / changelog (markdown dari GitHub release body).
  final String? releaseNotes;

  /// Pesan buat ditampilkan user — kenapa tidak ada update, atau kenapa
  /// pengecekan gagal (offline, repo belum punya rilis, dst).
  final String? message;
}

/// Cek rilis terbaru di `github.com/reiky03/Aplikasi_Comic` (endpoint publik,
/// tanpa perlu token) dan bandingkan dengan [currentVersion] aplikasi
/// (`pubspec.yaml`). Repo ini belum tentu selalu punya rilis publik — kalau
/// belum ada, dikasih tau apa adanya (bukan dianggap "sudah versi terbaru").
Future<AppUpdateResult> checkForAppUpdate({
  required String currentVersion,
}) async {
  final uri = Uri.parse(
    'https://api.github.com/repos/reiky03/Aplikasi_Comic/releases/latest',
  );
  try {
    final res = await http
        .get(
          uri,
          headers: {
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'Kizen-App/$currentVersion',
          },
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 404) {
      return const AppUpdateResult(
        hasUpdate: false,
        message: 'Belum ada rilis publik di GitHub.',
      );
    }

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final tag = (data['tag_name'] as String? ?? '').trim();
      final latest = tag.startsWith('v') ? tag.substring(1) : tag;
      if (latest.isNotEmpty) {
        final isNewer = _isVersionNewer(latest, currentVersion);

        // Cari aset file .apk dari daftar release assets
        final assets = (data['assets'] as List<dynamic>?) ?? [];
        Map<String, dynamic>? apkAsset;
        for (final item in assets) {
          if (item is Map<String, dynamic>) {
            final name = (item['name'] as String? ?? '').toLowerCase();
            if (name.endsWith('.apk')) {
              apkAsset = item;
              break;
            }
          }
        }

        final apkUrl = apkAsset?['browser_download_url'] as String?;
        final apkName = apkAsset?['name'] as String?;
        final apkSize = apkAsset?['size'] as int?;
        final releaseTitle = data['name'] as String?;
        final releaseNotes = data['body'] as String?;
        final releaseUrl = data['html_url'] as String?;

        return AppUpdateResult(
          hasUpdate: isNewer,
          latestVersion: latest,
          releaseUrl: releaseUrl,
          apkUrl: apkUrl,
          apkName: apkName,
          apkSize: apkSize,
          releaseTitle: releaseTitle,
          releaseNotes: releaseNotes,
          message: isNewer ? null : 'Sudah pakai versi terbaru (v$currentVersion).',
        );
      }
    }

    // Jika API terkena Rate Limit (HTTP 403) atau respons non-200, gunakan fallback Web Redirect
    final fallback = await _checkViaWebRedirect(currentVersion);
    if (fallback != null) {
      return fallback;
    }

    if (res.statusCode != 200) {
      return AppUpdateResult(
        hasUpdate: false,
        message: 'Gagal cek pembaruan (kode ${res.statusCode}).',
      );
    }

    return const AppUpdateResult(
      hasUpdate: false,
      message: 'Rilis ditemukan tapi nomor versinya tidak terbaca.',
    );
  } on TimeoutException {
    final fallback = await _checkViaWebRedirect(currentVersion);
    if (fallback != null) {
      return fallback;
    }
    return const AppUpdateResult(
      hasUpdate: false,
      message: 'Waktu cek pembaruan habis — cek koneksi internet.',
    );
  } catch (e) {
    final fallback = await _checkViaWebRedirect(currentVersion);
    if (fallback != null) {
      return fallback;
    }
    return AppUpdateResult(hasUpdate: false, message: 'Gagal cek pembaruan: $e');
  }
}

/// Fallback cek rilis langsung lewat HTTP redirect browser GitHub tanpa batasan kuota API (Rate Limit 60/jam).
Future<AppUpdateResult?> _checkViaWebRedirect(String currentVersion) async {
  try {
    final client = http.Client();
    final req = http.Request(
      'GET',
      Uri.parse('https://github.com/reiky03/Aplikasi_Comic/releases/latest'),
    );
    req.followRedirects = false;
    req.headers['User-Agent'] = 'Mozilla/5.0 (Linux; Android 14; Mobile)';
    final streamed = await client.send(req).timeout(const Duration(seconds: 6));
    client.close();

    final location = streamed.headers['location'] ?? '';
    if (location.isNotEmpty) {
      final uri = Uri.tryParse(location);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        final tag = uri.pathSegments.last.trim();
        final latest = tag.startsWith('v') ? tag.substring(1) : tag;
        if (latest.isNotEmpty) {
          final isNewer = _isVersionNewer(latest, currentVersion);
          final apkName = 'kizen-$tag.apk';
          final apkUrl =
              'https://github.com/reiky03/Aplikasi_Comic/releases/download/$tag/$apkName';
          return AppUpdateResult(
            hasUpdate: isNewer,
            latestVersion: latest,
            releaseUrl: location,
            apkUrl: apkUrl,
            apkName: apkName,
            releaseTitle: 'Kizen $tag',
            releaseNotes: 'Pembaruan versi terbaru Kizen $tag dari GitHub Releases.',
            message: isNewer ? null : 'Sudah pakai versi terbaru (v$currentVersion).',
          );
        }
      }
    }
  } catch (_) {}
  return null;
}

/// Bandingkan dua versi semver ("1.2.0" vs "1.10.0") secara numerik per
/// segmen — perbandingan string biasa salah untuk kasus "1.10" < "1.2".
bool _isVersionNewer(String latest, String current) {
  List<int> parse(String v) => v
      .split('.')
      .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
  final a = parse(latest);
  final b = parse(current);
  for (var i = 0; i < a.length || i < b.length; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}
