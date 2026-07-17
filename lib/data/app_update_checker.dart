import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Hasil cek rilis terbaru Kizen di GitHub — lihat [checkForAppUpdate].
class AppUpdateResult {
  const AppUpdateResult({
    required this.hasUpdate,
    this.latestVersion,
    this.releaseUrl,
    this.message,
  });

  final bool hasUpdate;

  /// Nomor versi rilis terbaru (tanpa prefix "v"), null kalau gagal/tidak ada.
  final String? latestVersion;

  /// Link halaman rilis di GitHub, dibuka kalau user pilih "Buka rilis".
  final String? releaseUrl;

  /// Pesan buat ditampilkan user — kenapa tidak ada update, atau kenapa
  /// pengecekan gagal (offline, repo belum punya rilis, dst).
  final String? message;
}

/// Cek rilis terbaru di `github.com/reiky03/Aplikasi_Comic` (endpoint publik,
/// tanpa perlu token) dan bandingkan dengan [currentVersion] aplikasi
/// (`pubspec.yaml`). Repo ini belum tentu selalu punya rilis publik — kalau
/// belum ada, dikasih tau apa adanya (bukan dianggap "sudah versi terbaru").
Future<AppUpdateResult> checkForAppUpdate({required String currentVersion}) async {
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
    return AppUpdateResult(
      hasUpdate: isNewer,
      latestVersion: latest,
      releaseUrl: data['html_url'] as String?,
      message: isNewer ? null : 'Sudah pakai versi terbaru.',
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
