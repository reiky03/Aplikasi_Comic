import 'package:flutter_test/flutter_test.dart';

import 'package:aplikasi_komik/data/library_state.dart';

void main() {
  test('normalisasi judul mengabaikan spasi dan tanda baca umum', () {
    expect(normalizeLibraryTitle('  Solo-Leveling!! '), 'solo leveling');
    expect(sameLibraryTitle('Solo Leveling', 'solo-leveling!'), isTrue);
  });

  test('judul dengan susunan kata berbeda bukan duplikat', () {
    expect(sameLibraryTitle('Solo Leveling', 'Level Up Alone'), isFalse);
    expect(sameLibraryTitle('', '   '), isFalse);
  });

  test('judul yang terkandung sebagai frasa utuh dianggap duplikat', () {
    expect(
      sameLibraryTitle('Solo Leveling', 'Solo Leveling Official Translation'),
      isTrue,
    );
    expect(sameLibraryTitle('One', 'Someone Else'), isFalse);
  });
}
