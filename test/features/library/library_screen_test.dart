import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
