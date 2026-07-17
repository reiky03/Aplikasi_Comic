import 'package:aplikasi_komik/features/auth/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fake sign out removes the persisted session', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = FakeAuthRepository();

    await repository.signIn();
    expect(await repository.restoreSession(), isNotNull);

    await repository.signOut();
    expect(await repository.restoreSession(), isNull);
  });
}
