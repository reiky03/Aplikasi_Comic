import 'package:aplikasi_komik/data/extension_runtime.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('kizen/extension_runtime');
  const bridge = ExtensionRuntimeBridge(channel: channel);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('runtimeInfo membaca capability dari native bridge', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'runtimeInfo');
          return {
            'platform': 'android',
            'apiVersion': 1,
            'available': true,
            'message': 'ready',
            'capabilities': {
              'packageDiscovery': true,
              'apkClassLoading': false,
              'tachiyomiSourceApi': false,
              'tachiyomiSourceFactory': false,
              'networkBridge': false,
            },
          };
        });

    final info = await bridge.runtimeInfo();

    expect(info.platform, 'android');
    expect(info.apiVersion, 1);
    expect(info.available, isTrue);
    expect(info.capabilities.packageDiscovery, isTrue);
    expect(info.capabilities.apkClassLoading, isFalse);
  });

  test(
    'listInstalledExtensions mengurai package extension Tachiyomi',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'listInstalledExtensions');
            return [
              {
                'packageName': 'eu.kanade.tachiyomi.extension.id.komiku',
                'name': 'Tachiyomi: Komiku',
                'versionName': '1.4.2',
                'versionCode': 42,
                'installed': true,
              },
            ];
          });

      final extensions = await bridge.listInstalledExtensions();

      expect(extensions, hasLength(1));
      expect(
        extensions.first.packageName,
        'eu.kanade.tachiyomi.extension.id.komiku',
      );
      expect(extensions.first.versionCode, 42);
    },
  );

  test('readWebViewSession mengurai cookie native WebView', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'readWebViewSession');
          expect(call.arguments, {'url': 'https://reader.example'});
          return {
            'url': 'https://reader.example',
            'cookie': 'cf_clearance=token',
            'userAgent': 'WebView UA',
          };
        });

    final session = await bridge.readWebViewSession('https://reader.example');

    expect(session.cookie, 'cf_clearance=token');
    expect(session.userAgent, 'WebView UA');
  });

  test(
    'renderHtmlWithWebView mengirim header session ke native WebView',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'renderHtmlWithWebView');
            expect(call.arguments, {
              'url': 'https://reader.example',
              'sessionHeaders': {'Cookie': 'cf_clearance=token'},
            });
            return '<html><body>Rendered</body></html>';
          });

      final html = await bridge.renderHtmlWithWebView(
        'https://reader.example',
        sessionHeaders: {'Cookie': 'cf_clearance=token'},
      );

      expect(html, contains('Rendered'));
    },
  );

  test('probeUrl mengurai status akses jaringan', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'probeUrl');
          expect(call.arguments, {'url': 'https://omegascans.org'});
          return {
            'ok': false,
            'statusCode': 0,
            'finalUrl': 'https://omegascans.org',
            'blocked': true,
            'message': 'Hostname mismatch',
          };
        });

    final result = await bridge.probeUrl('https://omegascans.org');

    expect(result.ok, isFalse);
    expect(result.blocked, isTrue);
    expect(result.message, contains('Hostname'));
  });

  test('openVpnSettings memanggil native settings launcher', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'openVpnSettings');
          return true;
        });

    expect(await bridge.openVpnSettings(), isTrue);
  });

  test(
    'findInstalledExtensionForUrl memeriksa semua source dalam APK',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'listInstalledExtensions') {
              return [
                {
                  'packageName': 'eu.kanade.tachiyomi.extension.all.bundle',
                  'name': 'Bundle',
                  'versionCode': 1,
                },
              ];
            }
            if (call.method == 'listExtensionSources') {
              return [
                {
                  'packageName': 'eu.kanade.tachiyomi.extension.all.bundle',
                  'sourceDir': '/extension.apk',
                  'extensionClass': 'BundleFactory',
                  'className': 'ReaderSource',
                  'name': 'Reader',
                  'baseUrl': 'https://reader.example',
                  'lang': 'en',
                  'id': 42,
                  'supportsLatest': true,
                  'superclasses': <String>[],
                },
              ];
            }
            return null;
          });

      final match = await findInstalledExtensionForUrl(
        'https://www.reader.example/manga/foo',
        bridge: bridge,
      );

      expect(match?.source.name, 'Reader');
      expect(
        match?.package.packageName,
        'eu.kanade.tachiyomi.extension.all.bundle',
      );
    },
  );
}
