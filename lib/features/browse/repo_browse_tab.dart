import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/demo_state.dart';
import '../../data/repository_state.dart';
import '../../data/sources_state.dart';
import 'browse_screen.dart';
import 'source_detail_screen.dart';

const _langLabels = [
  ('ID', 'Indonesia'),
  ('EN', 'English'),
  ('JP', '日本語 (Jepang)'),
  ('KR', '한국어 (Korea)'),
  ('CN', '中文 (China)'),
];

const _langGroupNames = {
  'ID': 'Indonesia',
  'EN': 'English',
  'JP': 'Jepang',
  'KR': 'Korea',
  'CN': 'China',
};

/// Sheet "Bahasa aktif" — toggle bahasa global, live tanpa tombol apply.
void showLanguageSheet(BuildContext context) {
  showAppSheet<void>(
    context,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final activeLangs = ref.watch(activeLangsProvider);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSheetTitle('Bahasa aktif', bottomGap: 4),
            Text(
              'Komik dari repository akan dikelompokkan berdasarkan bahasa '
              'yang aktif.',
              style: AppTypography.jakarta(
                size: 12.5,
                weight: FontWeight.w400,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            for (final (id, label) in _langLabels)
              InkWell(
                onTap: () =>
                    ref.read(activeLangsProvider.notifier).toggle(id),
                borderRadius: BorderRadius.circular(11),
                highlightColor: AppColors.rowHighlight,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: AppTypography.jakarta(
                              size: 14, weight: FontWeight.w600),
                        ),
                      ),
                      AppPillSwitch(
                        value: activeLangs.contains(id),
                        onChanged: (_) =>
                            ref.read(activeLangsProvider.notifier).toggle(id),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

/// Konten sub-tab Repository — spek 08.
class RepoBrowseTab extends ConsumerWidget {
  const RepoBrowseTab({super.key, required this.onOpenRepoList});

  final VoidCallback onOpenRepoList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demoEmpty = ref.watch(demoRepoEmptyProvider);
    final repositories = demoEmpty
        ? const <ComicRepository>[]
        : ref.watch(repositoriesProvider);
    final activeLangs = ref.watch(activeLangsProvider);
    final bookmarks = ref.watch(repoBookmarksProvider);

    if (repositories.isEmpty) {
      return AppEmptyState(
        icon: const CustomPaint(
          size: Size.square(42),
          painter:
              RepoGlyphPainter(color: AppColors.emptyIcon, strokeWidth: 1.7),
        ),
        title: 'Belum ada repository',
        description: const TextSpan(
          text: 'Repository berisi banyak sumber sekaligus dalam satu link, '
              'mirip daftar extension. Tambahkan satu untuk langsung dapat '
              'banyak pilihan sumber.',
        ),
        ctaLabel: 'Tambah Repository',
        onCta: onOpenRepoList,
      );
    }

    if (activeLangs.isEmpty) {
      return _NoLangsPrompt(onPickLanguage: () => showLanguageSheet(context));
    }

    // Kelompokkan per bahasa aktif (urutan tetap ID, EN, JP, KR, CN).
    final orderedLangs = [
      for (final (id, _) in _langLabels)
        if (activeLangs.contains(id)) id,
    ];

    final bookmarkRows = <_RepoSourceRowData>[];
    for (final repo in repositories) {
      for (final rs in repo.sources) {
        final savedId = 'rp-${repo.id}-${rs.id}';
        if (bookmarks.contains(savedId)) {
          bookmarkRows.add(_RepoSourceRowData(repo: repo, source: rs));
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 120),
      children: [
        if (bookmarkRows.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Row(
              children: [
                const Icon(Icons.bookmark,
                    size: 13, color: AppColors.accentText),
                const SizedBox(width: 6),
                Text(
                  'DITANDAI',
                  style: AppTypography.jakarta(
                    size: 12,
                    weight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppColors.accentText,
                  ),
                ),
              ],
            ),
          ),
          for (final row in bookmarkRows)
            _RepoSourceRow(data: row, bookmarkedStyle: true),
          const SizedBox(height: 9),
        ],
        for (final lang in orderedLangs) ...[
          Builder(builder: (context) {
            final items = <_RepoSourceRowData>[
              for (final repo in repositories)
                for (final rs in repo.sources)
                  if (rs.lang == lang)
                    _RepoSourceRowData(repo: repo, source: rs),
            ];
            final label = _langGroupNames[lang] ?? lang;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                  child: Text(
                    '${label.toUpperCase()} · ${items.length}',
                    style: AppTypography.jakarta(
                      size: 12,
                      weight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
                    child: Text(
                      'Belum ada sumber $label dari repository terpasang.',
                      style: AppTypography.jakarta(
                        size: 12.5,
                        weight: FontWeight.w400,
                        color: AppColors.textFaint,
                      ),
                    ),
                  )
                else
                  for (final row in items) _RepoSourceRow(data: row),
                const SizedBox(height: 9),
              ],
            );
          }),
        ],
      ],
    );
  }
}

class _NoLangsPrompt extends StatelessWidget {
  const _NoLangsPrompt({required this.onPickLanguage});

  final VoidCallback onPickLanguage;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 0, 30, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surfaceEmptyIcon,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: const Icon(LucideIcons.globe,
                  size: 32, color: AppColors.emptyIcon),
            ),
            const SizedBox(height: 14),
            Text(
              'Aktifkan bahasa dulu',
              style: AppTypography.jakarta(size: 15, weight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 250),
              child: Text(
                'Pilih bahasa yang ingin ditampilkan, komik dari repository '
                'akan dikelompokkan otomatis per bahasa.',
                textAlign: TextAlign.center,
                style: AppTypography.jakarta(
                  size: 13,
                  weight: FontWeight.w400,
                  height: 1.5,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: onPickLanguage,
              borderRadius: BorderRadius.circular(13),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  'Pilih Bahasa',
                  style: AppTypography.jakarta(
                    size: 13.5,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepoSourceRowData {
  const _RepoSourceRowData({required this.repo, required this.source});

  final ComicRepository repo;
  final RepoSource source;

  String get savedId => 'rp-${repo.id}-${source.id}';

  /// Sumber sintetis untuk dibuka di Source Detail (read-only, tidak
  /// menambah ke Sumber Saya).
  ComicSource toSyntheticSource() => ComicSource(
        id: savedId,
        name: source.name,
        url: repo.url,
        lang: source.lang,
        hue: source.hue,
      );
}

class _RepoSourceRow extends ConsumerWidget {
  const _RepoSourceRow({required this.data, this.bookmarkedStyle = false});

  final _RepoSourceRowData data;

  /// true untuk row di section "Ditandai" (border accent-tinted).
  final bool bookmarkedStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(repoBookmarksProvider);
    final saved = bookmarks.contains(data.savedId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SourceDetailScreen(
                sourceId: data.savedId,
                fallbackSource: data.toSyntheticSource(),
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: bookmarkedStyle
                  ? const Color(0x407C5CFF) // rgba(124,92,255,.25)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: comicCover(data.source.hue),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Text(
                  data.source.initial,
                  style: AppTypography.jakarta(
                    size: 15,
                    weight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.source.name,
                      style: AppTypography.jakarta(
                          size: 13.5, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.repo.name,
                      style: AppTypography.jakarta(
                        size: 11,
                        weight: FontWeight.w400,
                        color: AppColors.textFaintestAlt,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  ref
                      .read(repoBookmarksProvider.notifier)
                      .toggle(data.savedId);
                  AppToast.show(
                    context,
                    saved
                        ? 'Ditandai dibatalkan'
                        : '${data.source.name} ditandai',
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: saved ? const Color(0x247C5CFF) : null,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: saved
                          ? const Color(0x807C5CFF)
                          : AppColors.borderStrong,
                    ),
                  ),
                  child: Icon(
                    saved ? Icons.bookmark : AppIcons.bookmark,
                    size: 16,
                    color:
                        saved ? AppColors.accentText : AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(AppIcons.forward,
                  size: 16, color: AppColors.textFaintest),
            ],
          ),
        ),
      ),
    );
  }
}
