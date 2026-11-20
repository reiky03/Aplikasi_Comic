import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aplikasi_komik/data/library_state.dart';
import 'package:aplikasi_komik/data/models.dart';

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

  test('identitas chapter mengabaikan fragment dan slash penutup', () {
    expect(
      sameChapterIdentity(
        'https://contoh.test/chapter-10/#reader',
        'https://contoh.test/chapter-10',
      ),
      isTrue,
    );
    expect(
      sameChapterIdentity(
        'https://contoh.test/chapter-10',
        'https://contoh.test/chapter-11',
      ),
      isFalse,
    );
  });

  test('Comic mencari progres dan status baca lewat URL sebelum nomor', () {
    const comic = Comic(
      id: 'shifted',
      title: 'Shifted Chapters',
      src: 'Test',
      hue: 0,
      ch: 301,
      readChapterUrls: {'https://contoh.test/chapter-a'},
      chapterProgress: {
        300: ChapterProgress(
          page: 3,
          pages: 16,
          chapterUrl: 'https://contoh.test/chapter-a',
        ),
      },
    );

    expect(
      comic
          .progressForChapter(301, chapterUrl: 'https://contoh.test/chapter-a/')
          ?.page,
      3,
    );
    expect(
      comic.progressForChapter(
        300,
        chapterUrl: 'https://contoh.test/chapter-b',
      ),
      isNull,
    );
    expect(
      comic.isChapterRead(301, chapterUrl: 'https://contoh.test/chapter-a'),
      isTrue,
    );
    expect(
      comic.isChapterRead(300, chapterUrl: 'https://contoh.test/chapter-b'),
      isFalse,
    );
  });

  test(
    'progres URL berbeda tidak saling timpa pada nomor sintetis sama',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(libraryProvider.notifier);

      await notifier.updateProgress(
        'c1',
        read: 40,
        page: 3,
        pages: 16,
        chapterUrl: 'https://contoh.test/chapter-a',
      );
      await notifier.updateProgress(
        'c1',
        read: 40,
        page: 4,
        pages: 16,
        chapterUrl: 'https://contoh.test/chapter-b',
      );

      var comic = container
          .read(libraryProvider)
          .firstWhere((item) => item.id == 'c1');
      expect(
        comic
            .progressForChapter(41, chapterUrl: 'https://contoh.test/chapter-a')
            ?.page,
        3,
      );
      expect(
        comic
            .progressForChapter(40, chapterUrl: 'https://contoh.test/chapter-b')
            ?.page,
        4,
      );
      expect(comic.chapterProgress, hasLength(2));

      await notifier.updateProgress(
        'c1',
        read: 40,
        page: 16,
        pages: 16,
        chapterUrl: 'https://contoh.test/chapter-b',
        completed: true,
      );
      comic = container
          .read(libraryProvider)
          .firstWhere((item) => item.id == 'c1');
      expect(
        comic.isChapterRead(40, chapterUrl: 'https://contoh.test/chapter-b'),
        isTrue,
      );
      expect(
        comic.progressForChapter(
          40,
          chapterUrl: 'https://contoh.test/chapter-b',
        ),
        isNull,
      );
      expect(
        comic
            .progressForChapter(41, chapterUrl: 'https://contoh.test/chapter-a')
            ?.page,
        3,
      );
    },
  );

  test('domain manga Library bisa diperbarui tanpa mengubah progres', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(libraryProvider.notifier);
    await notifier.add(
      const Comic(
        id: 'domain-migration',
        title: 'Domain Migration',
        src: 'Ikiru',
        hue: 10,
        ch: 20,
        read: 7,
        sourceMangaUrl: 'https://domain-lama.test/manga/domain-migration',
        chapterProgress: {7: ChapterProgress(page: 3, pages: 12)},
      ),
    );

    await notifier.updateSourceMangaUrl(
      'domain-migration',
      'https://domain-baru.test/manga/domain-migration',
    );

    final comic = container
        .read(libraryProvider)
        .firstWhere((item) => item.id == 'domain-migration');
    expect(
      comic.sourceMangaUrl,
      'https://domain-baru.test/manga/domain-migration',
    );
    expect(comic.read, 7);
    expect(comic.chapterProgress[7]?.page, 3);
  });

  test('groupComicsBySource mengelompokkan komik berdasarkan src dengan rapi', () {
    const list = [
      Comic(id: '1', title: 'A', src: 'Kiryuu', hue: 0, ch: 10),
      Comic(id: '2', title: 'B', src: 'Komiku', hue: 0, ch: 10),
      Comic(id: '3', title: 'C', src: 'Kiryuu', hue: 0, ch: 10),
      Comic(id: '4', title: 'D', src: '', hue: 0, ch: 10),
    ];

    final grouped = groupComicsBySource(list);
    expect(grouped.keys, containsAll(['Kiryuu', 'Komiku', 'Sumber Tidak Diketahui']));
    expect(grouped['Kiryuu']!.map((c) => c.id), ['1', '3']);
    expect(grouped['Komiku']!.map((c) => c.id), ['2']);
    expect(grouped['Sumber Tidak Diketahui']!.map((c) => c.id), ['4']);
  });

  test('LibraryNotifier mendukung operasi batch: pindah koleksi & hapus', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(libraryProvider.notifier);

    // Initial state punya c1..c8 di in-memory demo
    final initialIds = container.read(libraryProvider).map((c) => c.id).toSet();
    expect(initialIds, containsAll(['c1', 'c2', 'c3']));

    // Pindahkan c1 dan c2 ke koleksi 'custom-col'
    await notifier.moveToCollectionBatch(['c1', 'c2'], 'custom-col');
    var lib = container.read(libraryProvider);
    expect(lib.firstWhere((c) => c.id == 'c1').col, 'custom-col');
    expect(lib.firstWhere((c) => c.id == 'c2').col, 'custom-col');

    // Hapus c1 dan c2 sekaligus
    await notifier.removeBatch(['c1', 'c2']);
    lib = container.read(libraryProvider);
    expect(lib.any((c) => c.id == 'c1'), isFalse);
    expect(lib.any((c) => c.id == 'c2'), isFalse);
  });

  test('LibraryNotifier dapat menghapus semua komik dari satu sumber', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(libraryProvider.notifier);

    await notifier.add(const Comic(id: 's1', title: 'S1', src: 'WebSpecial', hue: 0, ch: 10));
    await notifier.add(const Comic(id: 's2', title: 'S2', src: 'WebSpecial', hue: 0, ch: 10));
    await notifier.add(const Comic(id: 'k1', title: 'K1', src: 'OtherWeb', hue: 0, ch: 10));

    expect(container.read(libraryProvider).any((c) => c.id == 's1'), isTrue);
    expect(container.read(libraryProvider).any((c) => c.id == 's2'), isTrue);

    await notifier.removeBySource('WebSpecial');

    final lib = container.read(libraryProvider);
    expect(lib.any((c) => c.id == 's1'), isFalse);
    expect(lib.any((c) => c.id == 's2'), isFalse);
    expect(lib.any((c) => c.id == 'k1'), isTrue);
  });

  test('LibraryNotifier migrateComicsForDomainChange merebase mangaUrl, cover, dan chapter', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(libraryProvider.notifier);

    await notifier.add(const Comic(
      id: 'cm1',
      title: 'Solo Leveling',
      src: 'KomikCast',
      hue: 0,
      ch: 100,
      sourceMangaUrl: 'https://komikcast01.com/manga/solo-leveling/',
      coverUrl: 'https://komikcast01.com/covers/sl.jpg',
      lastChapterUrl: 'https://komikcast01.com/manga/solo-leveling-ch-100/',
      readChapterUrls: {'https://komikcast01.com/manga/solo-leveling-ch-1/'},
    ));
    await notifier.add(const Comic(
      id: 'cm2',
      title: 'Martial Peak',
      src: 'KomikIndo',
      hue: 0,
      ch: 500,
      sourceMangaUrl: 'https://komikindo.ch/manga/martial-peak/',
    ));

    final count = await notifier.migrateComicsForDomainChange(
      sourceName: 'KomikCast',
      oldUrl: 'https://komikcast01.com',
      newUrl: 'https://komikcast02.me',
      oldUrlAliases: ['komikcast.bz'],
    );

    expect(count, 1);
    final lib = container.read(libraryProvider);
    final sl = lib.firstWhere((c) => c.id == 'cm1');
    expect(sl.sourceMangaUrl, 'https://komikcast02.me/manga/solo-leveling/');
    expect(sl.coverUrl, 'https://komikcast02.me/covers/sl.jpg');
    expect(sl.lastChapterUrl, 'https://komikcast02.me/manga/solo-leveling-ch-100/');
    expect(sl.readChapterUrls, {'https://komikcast02.me/manga/solo-leveling-ch-1/'});

    final mp = lib.firstWhere((c) => c.id == 'cm2');
    expect(mp.sourceMangaUrl, 'https://komikindo.ch/manga/martial-peak/');
  });

  test('LibraryNotifier migrateComicsForDomainChange tidak merusak cover CDN eksternal dan tidak memigrasikan sumber berbeda', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(libraryProvider.notifier);

    await notifier.add(const Comic(
      id: 'cm-ext',
      title: 'Manga with Cloudinary Cover',
      src: 'KomikCast',
      hue: 0,
      ch: 10,
      sourceMangaUrl: 'https://komikcast01.com/manga/test-ext/',
      coverUrl: 'https://res.cloudinary.com/demo/image/upload/sample.jpg',
    ));

    await notifier.add(const Comic(
      id: 'cm-unrelated',
      title: 'Unrelated Manga',
      src: 'KomikStation', // Bukan KomikCast
      hue: 0,
      ch: 5,
      sourceMangaUrl: 'https://komikstation.example/manga/test/',
      coverUrl: 'https://komikstation.example/cover.jpg',
    ));

    final count = await notifier.migrateComicsForDomainChange(
      sourceName: 'KomikCast',
      oldUrl: 'https://komikcast01.com',
      newUrl: 'https://komikcast02.me',
    );

    expect(count, 1);
    final lib = container.read(libraryProvider);
    final ext = lib.firstWhere((c) => c.id == 'cm-ext');
    expect(ext.sourceMangaUrl, 'https://komikcast02.me/manga/test-ext/');
    // Cover eksternal di Cloudinary tidak boleh tersentuh atau di-rebase
    expect(ext.coverUrl, 'https://res.cloudinary.com/demo/image/upload/sample.jpg');

    final unrelated = lib.firstWhere((c) => c.id == 'cm-unrelated');
    expect(unrelated.sourceMangaUrl, 'https://komikstation.example/manga/test/');
    expect(unrelated.coverUrl, 'https://komikstation.example/cover.jpg');
  });

  test('Comic dan ChapterProgress operator == dan hashCode mendeteksi kesamaan', () {
    const c1 = Comic(
      id: 'c1',
      title: 'Solo Leveling',
      src: 'Shinigami',
      hue: 200,
      ch: 100,
      readChapters: {1, 2},
      readChapterUrls: {'https://s1.shinigami.mx/ch/1'},
      chapterProgress: {
        1: ChapterProgress(page: 10, pages: 20, chapterUrl: 'ch1', chapterLabel: 'Ch. 1'),
      },
    );
    const c2 = Comic(
      id: 'c1',
      title: 'Solo Leveling',
      src: 'Shinigami',
      hue: 200,
      ch: 100,
      readChapters: {1, 2},
      readChapterUrls: {'https://s1.shinigami.mx/ch/1'},
      chapterProgress: {
        1: ChapterProgress(page: 10, pages: 20, chapterUrl: 'ch1', chapterLabel: 'Ch. 1'),
      },
    );

    expect(c1 == c2, isTrue);
    expect(c1.hashCode, c2.hashCode);

    final c3 = c1.copyWith(unread: 5);
    expect(c1 == c3, isFalse);
  });
}
