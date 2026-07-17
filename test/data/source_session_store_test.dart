import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aplikasi_komik/data/source_session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SourceSessionStore.clearAll();
  });

  test('session cookie tersimpan lokal dan berlaku untuk subdomain', () async {
    await SourceSessionStore.save(
      url: 'https://reader.example/challenge',
      cookie: 'cf_clearance=token',
      userAgent: 'Browser UA',
    );

    expect(SourceSessionStore.headersFor('https://cdn.reader.example/page'), {
      'Cookie': 'cf_clearance=token',
      'User-Agent': 'Browser UA',
    });
    expect(SourceSessionStore.headersFor('https://unrelated.example'), isEmpty);
  });
}
