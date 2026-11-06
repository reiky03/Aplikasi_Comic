import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/library_state.dart';
import '../../data/models.dart';
import '../../data/updates_state.dart';
import '../detail/comic_detail_screen.dart';

/// Tab Updates — spek 05: feed chapter baru per tanggal + refresh.
class UpdatesScreen extends ConsumerStatefulWidget {
  const UpdatesScreen({super.key});

  @override
  ConsumerState<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends ConsumerState<UpdatesScreen> {
  bool _refreshing = false;
  bool _autoRefreshScheduled = false;
  DateTime? _selectedDate;

  Future<void> _pickDate() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
      helpText: 'Pilih tanggal update',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (!mounted || picked == null) return;
    setState(() => _selectedDate = DateUtils.dateOnly(picked));
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final result = await ref.read(updatesProvider.notifier).refresh();
    if (!mounted) return;
    setState(() => _refreshing = false);
    if (silent) return;
    AppToast.show(context, switch (result) {
      UpdateCheckResult(checked: 0) =>
        'Belum ada komik dari sumber asli di Library buat dicek',
      UpdateCheckResult(updated: 0, failed: 0) => 'Tidak ada chapter baru',
      UpdateCheckResult(updated: 0) =>
        '${result.failed} sumber gagal diperiksa, tidak ada chapter baru',
      _ =>
        '${result.updated} komik ada chapter baru'
            '${result.failed > 0 ? ' · ${result.failed} sumber gagal diperiksa' : ''}',
    });
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final libraryById = {for (final comic in library) comic.id: comic};
    final allEntries = ref
        .watch(updatesProvider)
        .where((entry) => libraryById.containsKey(entry.comicId))
        .toList();
    final entries = filterUpdatesByDate(allEntries, _selectedDate);

    if (!_autoRefreshScheduled && library.isNotEmpty) {
      _autoRefreshScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refresh(silent: true);
      });
    }

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
                  child: Text('Updates', style: AppTypography.screenTitle),
                ),
                AppHeaderIconButton(
                  icon: LucideIcons.calendarDays,
                  onTap: _pickDate,
                ),
                const SizedBox(width: 8),
                if (_refreshing)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const AppSpinner(
                      size: 17,
                      strokeWidth: 2,
                      color: AppColors.menuIcon,
                    ),
                  )
                else
                  AppHeaderIconButton(
                    icon: LucideIcons.rotateCw,
                    onTap: _refresh,
                  ),
              ],
            ),
          ),
          if (_selectedDate case final date?)
            _DateFilterBar(
              label: _formatDate(date),
              onClear: () => setState(() => _selectedDate = null),
            ),
          Expanded(
            child: entries.isEmpty
                ? _buildEmptyState(filtered: _selectedDate != null)
                : _buildFeed(entries, libraryById),
          ),
        ],
      ),
    );
  }

  /// Lazy (`ListView.builder`) — daftar biasa (bukan `ListView` +
  /// `children` eager) supaya feed dengan banyak entri (chapter baru dari
  /// banyak komik, numpuk seiring waktu) tidak nge-lag, sama seperti fix
  /// daftar chapter di Comic Detail sebelumnya. Header grup tanggal
  /// diselipkan sebagai baris tersendiri di antara baris entri.
  Widget _buildFeed(List<UpdateEntry> entries, Map<String, Comic> libraryById) {
    final rows = <Object>[];
    String? currentGroup;
    for (final entry in entries) {
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
        final entry = row as UpdateEntry;
        return _UpdateRow(
          key: ValueKey(entry.comicId),
          entry: entry,
          coverUrl: entry.coverUrl ?? libraryById[entry.comicId]?.coverUrl,
          onTap: () => _openDetail(entry),
        );
      },
    );
  }

  Widget _buildEmptyState({required bool filtered}) {
    return AppEmptyState(
      icon: const Icon(AppIcons.updates),
      title: filtered
          ? 'Tidak ada update di tanggal ini'
          : 'Belum ada update terbaru',
      description: TextSpan(
        text: filtered
            ? 'Pilih tanggal lain atau hapus filter untuk melihat semua update.'
            : 'Chapter baru dari komik di library-mu akan muncul di sini.',
      ),
    );
  }

  /// Ambil komik ASLI dari Library (biar `sourceMangaUrl`/`coverUrl`/dst
  /// ikut terbawa ke Comic Detail & Reader, bukan versi tiruan) — fallback
  /// ke stub minimal kalau entrinya somehow sudah tidak ada di Library lagi.
  Comic _resolveComic(UpdateEntry entry) {
    final library = ref.read(libraryProvider);
    return library.where((c) => c.id == entry.comicId).firstOrNull ??
        Comic(
          id: entry.comicId,
          title: entry.title,
          src: entry.src,
          hue: entry.hue,
          ch: entry.ch,
          read: entry.ch - 1,
        );
  }

  void _openDetail(UpdateEntry entry) {
    final comic = _resolveComic(entry);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ComicDetailScreen(comic: comic, initialChapter: entry.ch),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  const months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class _DateFilterBar extends StatelessWidget {
  const _DateFilterBar({required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
      child: Container(
        height: 40,
        padding: const EdgeInsets.only(left: 12, right: 4),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(
              LucideIcons.calendarCheck,
              size: 17,
              color: AppColors.accentText,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.jakarta(
                  size: 12.5,
                  weight: FontWeight.w700,
                  color: AppColors.accentText,
                ),
              ),
            ),
            IconButton(
              onPressed: onClear,
              tooltip: 'Hapus filter tanggal',
              icon: const Icon(LucideIcons.x, size: 18),
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdateRow extends StatelessWidget {
  const _UpdateRow({
    super.key,
    required this.entry,
    required this.coverUrl,
    required this.onTap,
  });

  final UpdateEntry entry;
  final String? coverUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      highlightColor: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            RepaintBoundary(
              child: Container(
                width: 44,
                height: 58,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: comicCover(entry.hue),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: comicCoverContent(
                  coverUrl: coverUrl,
                  initial: entry.initial,
                  fontSize: 20,
                  cacheWidth: (44 * MediaQuery.devicePixelRatioOf(context))
                      .round(),
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
                      size: 14,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    entry.chLabel,
                    style: AppTypography.jakarta(
                      size: 12.5,
                      weight: FontWeight.w600,
                      color: AppColors.accentText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.src,
                    style: AppTypography.jakarta(
                      size: 11,
                      weight: FontWeight.w400,
                      color: AppColors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              entry.time,
              style: AppTypography.jakarta(
                size: 11,
                weight: FontWeight.w400,
                color: AppColors.textFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
