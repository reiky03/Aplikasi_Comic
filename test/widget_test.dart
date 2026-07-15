import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aplikasi_komik/main.dart';

void main() {
  testWidgets('Splash tampil lalu lanjut ke Login', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyComicApp()));

    // Splash: brand moment
    expect(find.text('My Comic'), findsOneWidget);
    expect(find.text('Baca dari sumbermu, di mana saja'), findsOneWidget);

    // Setelah ~1.7s tanpa sesi → Login
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump(const Duration(milliseconds: 400)); // transisi route
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}
