import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aplikasi_komik/main.dart';

void main() {
  testWidgets('App boots with dark theme', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyComicApp()));
    expect(find.text('My Comic'), findsOneWidget);
  });
}
