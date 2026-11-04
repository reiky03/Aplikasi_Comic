import 'dart:convert';
import 'package:aplikasi_komik/data/app_update_checker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('AppUpdateResult menyimpan metadata rilis dan APK lengkap', () {
    const res = AppUpdateResult(
      hasUpdate: true,
      latestVersion: '1.1.1',
      releaseUrl: 'https://github.com/reiky03/Aplikasi_Comic/releases/tag/v1.1.1',
      apkUrl: 'https://github.com/reiky03/Aplikasi_Comic/releases/download/v1.1.1/kizen-v1.1.1.apk',
      apkName: 'kizen-v1.1.1.apk',
      apkSize: 68729245,
      releaseTitle: 'Kizen v1.1.1',
      releaseNotes: 'Fitur in-app download',
    );

    expect(res.hasUpdate, isTrue);
    expect(res.latestVersion, '1.1.1');
    expect(res.apkName, 'kizen-v1.1.1.apk');
    expect(res.apkSize, 68729245);
    expect(res.releaseTitle, 'Kizen v1.1.1');
    expect(res.releaseNotes, 'Fitur in-app download');
  });

  test('Mock GitHub API response terurai dengan benar', () async {
    final mockJson = jsonEncode({
      'tag_name': 'v1.1.1',
      'name': 'Kizen v1.1.1 — Pembaruan Langsung',
      'body': '- In-app direct download APK\n- Perbaikan bug',
      'html_url': 'https://github.com/reiky03/Aplikasi_Comic/releases/tag/v1.1.1',
      'assets': [
        {
          'name': 'kizen-v1.1.1.apk',
          'size': 68000000,
          'browser_download_url':
              'https://github.com/reiky03/Aplikasi_Comic/releases/download/v1.1.1/kizen-v1.1.1.apk',
        },
      ],
    });

    final mockClient = MockClient((request) async {
      return http.Response(mockJson, 200, headers: {'content-type': 'application/json'});
    });

    // Jalankan parsing manual serupa checkForAppUpdate
    final data = jsonDecode(mockJson) as Map<String, dynamic>;
    final assets = data['assets'] as List;
    final apkAsset = assets.firstWhere((a) => (a['name'] as String).endsWith('.apk')) as Map<String, dynamic>;

    expect(apkAsset['name'], 'kizen-v1.1.1.apk');
    expect(apkAsset['browser_download_url'], contains('kizen-v1.1.1.apk'));
    expect(data['body'], contains('In-app direct download'));
    mockClient.close();
  });
}
