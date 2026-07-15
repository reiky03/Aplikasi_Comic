import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aplikasi_komik/core/widgets/widgets.dart';
import 'package:aplikasi_komik/main.dart';

void main() {
  testWidgets('App boots with bottom nav', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyComicApp()));
    expect(find.byType(AppBottomNav), findsOneWidget);
    for (final label in ['Library', 'Updates', 'History', 'Jelajahi', 'Setelan']) {
      expect(find.text(label), findsOneWidget);
    }
  });
}
