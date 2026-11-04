import 'package:flutter_test/flutter_test.dart';

import 'package:aplikasi_komik/data/models.dart';
import 'package:aplikasi_komik/features/browse/source_detail_screen.dart';

void main() {
  Comic comic(String id, String title) =>
      Comic(id: id, title: title, src: 'Source', hue: 10, ch: 0);

  test('pagination mempertahankan urutan dan membuang ID duplikat', () {
    final merged = mergeDiscoverResults(
      [comic('a', 'A'), comic('b', 'B')],
      [comic('b', 'B duplikat'), comic('c', 'C')],
    );

    expect(merged.map((item) => item.id), ['a', 'b', 'c']);
    expect(merged[1].title, 'B');
  });
}
