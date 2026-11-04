import 'package:flutter_test/flutter_test.dart';

import 'package:aplikasi_komik/data/source_url.dart';

void main() {
  test(
    'URL lama di-rebase ke domain aktif tanpa kehilangan path dan query',
    () {
      expect(
        rebaseSourceUrl(
          'https://domain-lama.test/manga/judul/chapter-10/?page=2#reader',
          'https://domain-baru.test',
        ),
        'https://domain-baru.test/manga/judul/chapter-10/?page=2#reader',
      );
      expect(
        rebaseSourceUrl('/manga/judul', 'domain-baru.test'),
        'https://domain-baru.test/manga/judul',
      );
    },
  );

  test('opaque ID dan subdomain API sumber yang sama tidak diubah', () {
    expect(rebaseSourceUrl('manga-uuid', 'https://reader.test'), 'manga-uuid');
    expect(
      rebaseSourceUrl(
        'https://api.reader.test/v1/manga/123',
        'https://reader.test',
      ),
      'https://api.reader.test/v1/manga/123',
    );
  });

  test('resource lintas domain cocok hanya jika path pentingnya sama', () {
    expect(
      sameSourceResourceIdentity(
        'https://lama.test/chapter/10/?utm_source=old#reader',
        'https://baru.test/chapter/10',
      ),
      isTrue,
    );
    expect(
      sameSourceResourceIdentity(
        'https://lama.test/chapter/10',
        'https://baru.test/chapter/11',
      ),
      isFalse,
    );
    expect(
      sameSourceResourceIdentity('https://lama.test/', 'https://baru.test/'),
      isFalse,
    );
  });
}
