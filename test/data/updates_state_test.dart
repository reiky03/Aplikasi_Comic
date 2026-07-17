import 'package:flutter_test/flutter_test.dart';
import 'package:aplikasi_komik/data/updates_state.dart';

void main() {
  group('decideLatestChapterUpdate', () {
    test('creates a feed snapshot without unread on first equal baseline', () {
      final decision = decideLatestChapterUpdate(
        knownLatestUrl: null,
        knownTotal: 16,
        currentEntry: null,
        fetchedTotal: 16,
        fetchedLatestUrl: '/chapter-16',
        fetchedLatestName: 'Chapter 16',
        coverUrl: 'https://example.com/cover.jpg',
      );

      expect(decision.hasNew, isFalse);
      expect(decision.latestChanged, isTrue);
      expect(decision.deltaUnread, 0);
    });

    test('detects a different newest URL and increments unread', () {
      final decision = decideLatestChapterUpdate(
        knownLatestUrl: '/chapter-15',
        knownTotal: 15,
        currentEntry: null,
        fetchedTotal: 16,
        fetchedLatestUrl: '/chapter-16',
        fetchedLatestName: 'Chapter 16',
        coverUrl: null,
      );

      expect(decision.hasNew, isTrue);
      expect(decision.latestChanged, isTrue);
      expect(decision.deltaUnread, 1);
    });

    test('does not rewrite an unchanged latest snapshot', () {
      final entry = UpdateEntry(
        comicId: 'comic-1',
        title: 'Comic',
        src: 'Source',
        hue: 10,
        ch: 16,
        detectedAt: DateTime(2026),
        chapterLabel: 'Chapter 16',
        chapterUrl: '/chapter-16',
        coverUrl: 'https://example.com/cover.jpg',
      );
      final decision = decideLatestChapterUpdate(
        knownLatestUrl: '/chapter-16',
        knownTotal: 16,
        currentEntry: entry,
        fetchedTotal: 16,
        fetchedLatestUrl: '/chapter-16',
        fetchedLatestName: 'Chapter 16',
        coverUrl: 'https://example.com/cover.jpg',
      );

      expect(decision.hasNew, isFalse);
      expect(decision.latestChanged, isFalse);
      expect(decision.deltaUnread, 0);
    });
  });

  test('UpdateEntry preserves chapter identity and cover metadata', () {
    final entry = UpdateEntry(
      comicId: 'comic-1',
      title: 'Comic',
      src: 'Source',
      hue: 10,
      ch: 16,
      detectedAt: DateTime(2026),
      chapterLabel: 'Chapter 16',
      chapterUrl: '/chapter-16',
      coverUrl: 'https://example.com/cover.jpg',
    );

    final restored = UpdateEntry.fromMap('comic-1', entry.toMap());
    expect(restored.chapterUrl, '/chapter-16');
    expect(restored.chapterLabel, 'Chapter 16');
    expect(restored.coverUrl, 'https://example.com/cover.jpg');
  });
}
