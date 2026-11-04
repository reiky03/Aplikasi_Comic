import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aplikasi_komik/data/bookmarks_state.dart';

void main() {
  test(
    'ID bookmark sumber asli stabil terhadap nomor chapter yang bergeser',
    () {
      final before = BookmarksNotifier.idFor(
        'comic',
        300,
        4,
        chapterUrl: 'https://contoh.test/chapter-a/',
      );
      final after = BookmarksNotifier.idFor(
        'comic',
        301,
        4,
        chapterUrl: 'https://contoh.test/chapter-a#reader',
      );
      final other = BookmarksNotifier.idFor(
        'comic',
        300,
        4,
        chapterUrl: 'https://contoh.test/chapter-b',
      );

      expect(after, before);
      expect(other, isNot(before));
    },
  );

  test(
    'bookmark URL berbeda pada nomor dan halaman sama tidak tertimpa',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(bookmarksProvider.notifier);

      Future<void> toggle(String chapterUrl) => notifier.toggle(
        comicId: 'comic',
        title: 'Comic',
        src: 'Test',
        hue: 0,
        chNum: 300,
        chapterLabel: 'Chapter 300',
        page: 4,
        pages: 16,
        chapterUrl: chapterUrl,
      );

      await toggle('https://contoh.test/chapter-a');
      await toggle('https://contoh.test/chapter-b');
      expect(container.read(bookmarksProvider), hasLength(2));

      await toggle('https://contoh.test/chapter-a/');
      final remaining = container.read(bookmarksProvider);
      expect(remaining, hasLength(1));
      expect(remaining.single.chapterUrl, 'https://contoh.test/chapter-b');
    },
  );
}
