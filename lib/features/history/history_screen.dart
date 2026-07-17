import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/demo_state.dart';
import '../../data/history_state.dart';
import '../../data/models.dart';
import '../../data/library_state.dart';
import '../detail/comic_detail_screen.dart';
import '../reader/reader_screen.dart';

/// Tab History — spek 06: lanjut baca + bersihkan riwayat.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demoEmpty = ref.watch(demoHistEmptyProvider);
    final history = demoEmpty
        ? const <HistoryEntry>[]
        : ref.watch(historyProvider);
    final libraryById = {
      for (final comic in ref.watch(libraryProvider)) comic.id: comic,
    };

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text('History', style: AppTypography.screenTitle),
                ),
                _ClearButton(
                  onTap: () {
                    ref.read(historyProvider.notifier).clear();
                    AppToast.show(context, 'Riwayat dibersihkan');
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: history.isEmpty
                ? const AppEmptyState(
                    icon: Icon(LucideIcons.clock),
                    title: 'Belum ada riwayat baca',
                    description: TextSpan(
                      text:
                          'Komik yang kamu baca akan muncul di sini agar '
                          'mudah dilanjutkan.',
                    ),
                  )
                : _buildFeed(context, ref, history, libraryById),
          ),
        ],
      ),
    );
  }

  /// Feed History dikelompokkan per tanggal ("Hari ini", "Kemarin", "2 hari
  /// lalu", dst) — header tanggal diselipkan sebagai baris tersendiri di
  /// antara baris entri, sama pola dengan tab Updates biar konsisten &
  /// gampang di-track. Tetap lazy (`ListView.builder`) supaya riwayat
  /// panjang tidak nge-lag: `rows` di-flatten jadi campuran `String`
  /// (header) + `HistoryEntry` (baris komik). `history` sendiri sudah
  /// terurut `readAt` desc dari notifier, jadi urutan grup otomatis benar.
  Widget _buildFeed(
    BuildContext context,
    WidgetRef ref,
    List<HistoryEntry> history,
    Map<String, Comic> libraryById,
  ) {
    final rows = <Object>[];
    String? currentGroup;
    for (final entry in history) {
      if (entry.dateGroup != currentGroup) {
        currentGroup = entry.dateGroup;
        rows.add(currentGroup);
      }
      rows.add(entry);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        if (row is String) {
          return Padding(
            key: ValueKey('header:$row:$i'),
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Text(
              row.toUpperCase(),
              style: AppTypography.jakarta(
                size: 12,
                weight: FontWeight.w800,
                letterSpacing: 0.6,
                color: AppColors.textMuted,
              ),
            ),
          );
        }
        final entry = row as HistoryEntry;
        return _HistoryRow(
          key: ValueKey(entry.comicId),
          entry: entry,
          coverUrl: entry.coverUrl ?? libraryById[entry.comicId]?.coverUrl,
          onTap: () => _openDetail(context, ref, entry),
          onPlay: () => _resumeReading(context, ref, entry),
        );
      },
    );
  }

  Comic _resolveComic(WidgetRef ref, HistoryEntry entry) {
    final library = ref.read(libraryProvider);
    return library.where((c) => c.id == entry.comicId).firstOrNull ??
        Comic(
          id: entry.comicId,
          title: entry.title,
          src: entry.src,
          hue: entry.hue,
          ch: entry.chNum,
          read: entry.chNum,
        );
  }

  void _openDetail(BuildContext context, WidgetRef ref, HistoryEntry entry) {
    final comic = _resolveComic(ref, entry);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ComicDetailScreen(comic: comic, initialChapter: entry.chNum),
      ),
    );
  }

  void _resumeReading(BuildContext context, WidgetRef ref, HistoryEntry entry) {
    final comic = _resolveComic(ref, entry);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReaderScreen(
          comic: comic,
          chapter: entry.chNum,
          initialChapterUrl: entry.chapterUrl,
        ),
      ),
    );
  }
}

class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.delete, size: 15, color: AppColors.menuIcon),
            const SizedBox(width: 6),
            Text(
              'Bersihkan',
              style: AppTypography.jakarta(
                size: 12.5,
                weight: FontWeight.w700,
                color: AppColors.menuIcon,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    super.key,
    required this.entry,
    required this.coverUrl,
    required this.onTap,
    required this.onPlay,
  });

  final HistoryEntry entry;
  final String? coverUrl;
  final VoidCallback onTap;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        highlightColor: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 64,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: comicCover(entry.hue),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: comicCoverContent(
                  coverUrl: coverUrl,
                  initial: entry.initial,
                  fontSize: 22,
                  cacheWidth: (48 * MediaQuery.devicePixelRatioOf(context))
                      .round(),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.jakarta(
                        size: 14.5,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.pageLabel,
                      style: AppTypography.jakarta(
                        size: 12.5,
                        weight: FontWeight.w400,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: SizedBox(
                        height: 4,
                        child: LinearProgressIndicator(
                          value: entry.progress,
                          backgroundColor: AppColors.surfaceSunken,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 13),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    entry.time,
                    style: AppTypography.jakarta(
                      size: 10.5,
                      weight: FontWeight.w400,
                      color: AppColors.textFaint,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: onPlay,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
