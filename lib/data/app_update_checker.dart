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
        .get(uri, headers: const {'Accept': 'application/vnd.github+json'})
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 404) {
      return const AppUpdateResult(
        hasUpdate: false,
        message: 'Belum ada rilis publik di GitHub.',
      );
    }
    if (res.statusCode != 200) {
      return AppUpdateResult(
        hasUpdate: false,
        message: 'Gagal cek pembaruan (kode ${res.statusCode}).',
      );
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final tag = (data['tag_name'] as String? ?? '').trim();
    final latest = tag.startsWith('v') ? tag.substring(1) : tag;
    if (latest.isEmpty) {
      return const AppUpdateResult(
        hasUpdate: false,
        message: 'Rilis ditemukan tapi nomor versinya tidak terbaca.',
      );
    }
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
  } on TimeoutException {
    return const AppUpdateResult(
      hasUpdate: false,
      message: 'Waktu cek pembaruan habis — cek koneksi internet.',
    );
  } catch (e) {
    return AppUpdateResult(hasUpdate: false, message: 'Gagal cek pembaruan: $e');
  }
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
