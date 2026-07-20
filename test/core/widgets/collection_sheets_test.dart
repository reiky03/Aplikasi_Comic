import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aplikasi_komik/core/widgets/collection_sheets.dart';

void main() {
  testWidgets('ikon X meminta konfirmasi lalu membatalkan simpan', (
    tester,
  ) async {
    var removed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showCollectionPickerSheet(
                context,
                title: 'Pindahkan ke koleksi',
                collections: const [
                  SheetCollection(
                    id: 'manhwa',
                    name: 'Manhwa',
                    count: 25,
                    selected: true,
                  ),
                ],
                onPick: (_) {},
                onCreateAndPick: (_) {},
                onRemove: () => removed = true,
              ),
              child: const Text('Buka koleksi'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka koleksi'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('remove-saved-comic')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('remove-saved-comic')));
    await tester.pumpAndSettle();
    expect(find.text('Batalkan simpan?'), findsOneWidget);
    expect(removed, isFalse);

    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(removed, isTrue);
    expect(find.text('Pindahkan ke koleksi'), findsNothing);
  });

  testWidgets('peringatan judul duplikat menyediakan tiga keputusan', (
    tester,
  ) async {
    var result = DuplicateComicAction.cancel;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDuplicateComicSheet(
                  context,
                  title: 'Solo Leveling',
                  duplicateSources: const ['Source Lama'],
                );
              },
              child: const Text('Simpan komik'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Simpan komik'));
    await tester.pumpAndSettle();
    expect(find.text('Tetap tambah'), findsOneWidget);
    expect(find.text('Ganti yang lama'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);

    await tester.tap(find.text('Ganti yang lama'));
    await tester.pumpAndSettle();
    expect(result, DuplicateComicAction.replaceExisting);
  });
}
