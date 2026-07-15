import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/history_state.dart';
import '../../data/models.dart';
import '../../data/library_state.dart';
import '../detail/comic_detail_screen.dart';

/// Tab History — spek 06: lanjut baca + bersihkan riwayat.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);

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
                      text: 'Komik yang kamu baca akan muncul di sini agar '
                          'mudah dilanjutkan.',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
                    itemCount: history.length,
                    itemBuilder: (context, i) => _HistoryRow(
                      entry: history[i],
                      onTap: () => _openDetail(context, ref, history[i]),
                      onPlay: () => _resumeReading(context, history[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context, WidgetRef ref, HistoryEntry entry) {
    final library = ref.read(libraryProvider);
    final comic = library.where((c) => c.title == entry.title).firstOrNull ??
        Comic(
          id: 'x',
          title: entry.title,
          src: entry.src,
          hue: entry.hue,
          ch: entry.chNum,
          read: entry.chNum,
        );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ComicDetailScreen(comic: comic, initialChapter: entry.chNum),
      ),
    );
  }

  void _resumeReading(BuildContext context, HistoryEntry entry) {
    // TODO(13): langsung buka Reader di halaman terakhir dibaca.
    AppToast.show(context, 'Reader menyusul (spek 13)');
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
    required this.entry,
    required this.onTap,
    required this.onPlay,
  });

  final HistoryEntry entry;
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
                decoration: BoxDecoration(
                  gradient: comicCover(entry.hue),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  entry.initial,
                  style: AppTypography.jakarta(
                    size: 22,
                    weight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
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
                          size: 14.5, weight: FontWeight.w700),
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
