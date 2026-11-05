import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aplikasi_komik/data/models.dart';
import 'package:aplikasi_komik/features/library/library_screen.dart';

void main() {
  Comic comic(String id, {DateTime? addedAt}) =>
      Comic(id: id, title: id, src: 'Test', hue: 0, ch: 1, addedAt: addedAt);

  test('terakhir ditambahkan mengurutkan addedAt terbaru di depan', () {
    final result = sortLibraryComics([
      comic('lama', addedAt: DateTime.utc(2026, 7, 1)),
      comic('tanpa-tanggal'),
      comic('baru', addedAt: DateTime.utc(2026, 7, 20)),
      comic('lebih-baru', addedAt: DateTime.utc(2026, 7, 21)),
    ], LibrarySort.recentlyAdded);

    expect(result.map((comic) => comic.id), [
      'lebih-baru',
      'baru',
      'lama',
      'tanpa-tanggal',
    ]);
  });

  test('komik tanpa addedAt mempertahankan urutan relatifnya', () {
    final result = sortLibraryComics([
      comic('pertama'),
      comic('kedua'),
      comic('ketiga'),
    ], LibrarySort.recentlyAdded);

    expect(result.map((comic) => comic.id), ['pertama', 'kedua', 'ketiga']);
  });

  test('Comic membawa addedAt dari dokumen Firestore', () {
    final addedAt = DateTime.utc(2026, 7, 21, 14, 30);
    final result = Comic.fromMap('firestore', {
      'title': 'Firestore Comic',
      'addedAt': Timestamp.fromDate(addedAt),
    });

    expect(
      result.addedAt?.millisecondsSinceEpoch,
      addedAt.millisecondsSinceEpoch,
    );
  });

  testWidgets('LibraryScreen tidak menampilkan tab Semua dan default ke koleksi pertama', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: LibraryScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tab 'Semua' sudah dihapus
    expect(find.text('Semua'), findsNothing);

    // Koleksi pertama ('Sedang Dibaca') tampil
    expect(find.text('Sedang Dibaca'), findsOneWidget);
  });

  testWidgets('Multi-select mode menampilkan floating action button dan sheet aksi', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: LibraryScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Aktifkan mode pilih banyak lewat tombol checkSquare di header
    final multiSelectBtn = find.byIcon(LucideIcons.checkSquare).first;
    await tester.tap(multiSelectBtn);
    await tester.pumpAndSettle();

    // Floating action button muncul di layar
    expect(find.text('Pilih Komik'), findsOneWidget);

    // Pilih 1 komik (misal 'Echoes of the Void')
    final card = find.text('Echoes of the Void');
    expect(card, findsOneWidget);
    await tester.tap(card);
    await tester.pumpAndSettle();

    // Floating button berubah menjadi '1 Dipilih'
    expect(find.text('1 Dipilih'), findsOneWidget);

    // Ketuk floating button untuk membuka action sheet
    await tester.tap(find.text('1 Dipilih'));
    await tester.pumpAndSettle();

    // Action sheet muncul dengan opsi-opsi yang diminta
    expect(find.text('1 Komik Dipilih'), findsOneWidget);
    expect(find.text('Pindahkan ke Koleksi Lain'), findsOneWidget);
    expect(find.text('Tandai Selesai Dibaca'), findsOneWidget);
    expect(find.text('Hapus dari Library'), findsOneWidget);
    expect(find.text('Batal & Selesai'), findsOneWidget);
  });

  test('pembaruan terakhir mengurutkan update chapter terbaru di depan', () {
    final updateTimes = {
      'lama': DateTime.utc(2026, 7, 10),
      'baru': DateTime.utc(2026, 7, 28),
      'sedang': DateTime.utc(2026, 7, 19),
    };
    final result = sortLibraryComics([
      comic('lama'),
      comic('tanpa-update', addedAt: DateTime.utc(2026, 7, 1)),
      comic('sedang'),
      comic('baru'),
    ], LibrarySort.latestUpdate, updateTimes: updateTimes);

    expect(result.map((c) => c.id), [
      'baru',
      'sedang',
      'lama',
      'tanpa-update',
    ]);
  });

  testWidgets('swipe horizontal PageView di Library berpindah koleksi', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: LibraryScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Di koleksi pertama 'Sedang Dibaca', ada komik 'Echoes of the Void'
    expect(find.text('Echoes of the Void'), findsOneWidget);

    // Swipe ke kiri untuk pindah ke koleksi berikutnya ('Favorit')
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    // Sekarang komik koleksi Favorit ('Crimson Vow') tampil
    expect(find.text('Crimson Vow'), findsOneWidget);

    // Swipe kembali ke kanan untuk balik ke 'Sedang Dibaca'
    await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Echoes of the Void'), findsOneWidget);
  });
}
