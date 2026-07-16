import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/demo_state.dart';
import '../../data/repository_state.dart';
import '../../data/sources_state.dart';
import 'add_source_screen.dart';
import 'repo_browse_tab.dart';
import 'repository_screens.dart';
import 'source_detail_screen.dart';

enum BrowseSubTab { own, repo }

/// Entry point Add Source — dipakai FAB (HomeShell) & CTA empty state.
void openAddSource(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const AddSourceScreen()),
  );
}

/// Sub-tab aktif di Jelajahi (menentukan visibilitas FAB di HomeShell).
class BrowseSubTabNotifier extends Notifier<BrowseSubTab> {
  @override
  BrowseSubTab build() => BrowseSubTab.own;

  void set(BrowseSubTab tab) => state = tab;
}

final browseSubTabProvider =
    NotifierProvider<BrowseSubTabNotifier, BrowseSubTab>(
        BrowseSubTabNotifier.new);

/// Tab Jelajahi — spek 07 (Sumber Saya) & 08 (Repository).
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subTab = ref.watch(browseSubTabProvider);
    final activeLangs = ref.watch(activeLangsProvider);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Jelajahi', style: AppTypography.screenTitle),
                      const SizedBox(height: 2),
                      Text(
                        'Sumber komik yang kamu tambahkan',
                        style: AppTypography.jakarta(
                          size: 13,
                          weight: FontWeight.w400,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                _AccentIconButton(
                  onTap: _openLanguageSheet,
                  badgeCount: activeLangs.isEmpty ? null : activeLangs.length,
                  child: const Icon(LucideIcons.globe,
                      size: 20, color: AppColors.accentText),
                ),
                const SizedBox(width: 8),
                _AccentIconButton(
                  onTap: _openRepositoryList,
                  child: const CustomPaint(
                    size: Size.square(20),
                    painter: RepoGlyphPainter(color: AppColors.accentText),
                  ),
                ),
              ],
            ),
          ),
          // Sub-tab control
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: Row(
              children: [
                Expanded(
                  child: _subTabButton('Sumber Saya', BrowseSubTab.own, subTab),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _subTabButton('Repository', BrowseSubTab.repo, subTab),
                ),
              ],
            ),
          ),
          Expanded(
            child: subTab == BrowseSubTab.own
                ? _buildOwnTab()
                : _buildRepoTab(),
          ),
        ],
      ),
    );
  }

  Widget _subTabButton(String label, BrowseSubTab tab, BrowseSubTab active) {
    final isActive = tab == active;
    return InkWell(
      onTap: () => ref.read(browseSubTabProvider.notifier).set(tab),
      borderRadius: BorderRadius.circular(11),
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          label,
          style: AppTypography.jakarta(
            size: 13,
            weight: FontWeight.w700,
            color: isActive ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // --- Sumber Saya (07) ---

  Widget _buildOwnTab() {
    final demoEmpty = ref.watch(demoBrowseEmptyProvider);
    final sources =
        demoEmpty ? const <ComicSource>[] : ref.watch(sourcesProvider);
    final q = _search.trim().toLowerCase();
    final visible = sources
        .where((s) =>
            q.isEmpty ||
            s.name.toLowerCase().contains(q) ||
            s.url.toLowerCase().contains(q))
        .toList();

    if (sources.isEmpty) {
      return AppEmptyState(
        icon: const Icon(AppIcons.browse),
        title: 'Belum ada sumber komik',
        description: TextSpan(
          children: [
            const TextSpan(text: 'Tekan tombol '),
            TextSpan(
              text: '+',
              style: AppTypography.jakarta(
                size: 13.5,
                weight: FontWeight.w700,
                color: AppColors.accentText,
              ),
            ),
            const TextSpan(
                text:
                    ' untuk menambahkan sumber dari URL website komik favoritmu.'),
          ],
        ),
        ctaLabel: 'Tambah Sumber',
        onCta: _openAddSource,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(AppIcons.search,
                    size: 18, color: AppColors.textFaint),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _search = v),
                    cursorColor: AppColors.accent,
                    style: AppTypography.jakarta(
                        size: 14, weight: FontWeight.w400),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'Cari sumber…',
                      hintStyle: AppTypography.jakarta(
                        size: 14,
                        weight: FontWeight.w400,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(30, 50, 30, 0),
                  child: Text(
                    'Sumber tidak ditemukan',
                    textAlign: TextAlign.center,
                    style: AppTypography.jakarta(
                      size: 14,
                      weight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 120),
                  children: [
                    for (final source in visible)
                      SourceRow(
                        source: source,
                        onTap: () => _openSource(source),
                        onLongPress: () => _openSourceMenu(source),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Tekan + untuk menambah sumber baru',
                        textAlign: TextAlign.center,
                        style: AppTypography.jakarta(
                          size: 11.5,
                          weight: FontWeight.w400,
                          color: AppColors.textFaintest,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  // --- Repository (08) ---

  Widget _buildRepoTab() {
    return RepoBrowseTab(onOpenRepoList: _openRepositoryList);
  }

  void _openAddSource() => openAddSource(context);

  void _openSource(ComicSource source) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SourceDetailScreen(sourceId: source.id),
      ),
    );
  }

  void _openLanguageSheet() => showLanguageSheet(context);

  void _openRepositoryList() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RepositoryListScreen()),
    );
  }

  void _openSourceMenu(ComicSource source) {
    showSourceContextMenu(
      context,
      cover: comicCover(source.hue),
      title: source.name,
      subtitle: source.url,
      sourceActive: source.active,
      onOpenSource: () => _openSource(source),
      onEditSource: () => AppToast.show(context, 'Edit sumber (segera hadir)'),
      onToggleSource: () {
        ref.read(sourcesProvider.notifier).toggleActive(source.id);
        AppToast.show(
          context,
          source.active ? 'Sumber dinonaktifkan' : 'Sumber diaktifkan',
        );
      },
      onRemoveSource: () async {
        final confirmed = await showConfirmSheet(
          context,
          title: 'Hapus sumber?',
          message:
              '"${source.name}" akan dihapus dari daftar sumber kamu. '
              'Komik yang sudah tersimpan di Library tidak ikut terhapus.',
        );
        if (!confirmed || !mounted) return;
        ref.read(sourcesProvider.notifier).remove(source.id);
        if (mounted) AppToast.show(context, 'Sumber dihapus');
      },
    );
  }
}

/// Row sumber di daftar Sumber Saya.
class SourceRow extends StatelessWidget {
  const SourceRow({
    super.key,
    required this.source,
    required this.onTap,
    this.onLongPress,
  });

  final ComicSource source;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final status = source.statusMeta;
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: comicCover(source.hue),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Text(
                  source.initial,
                  style: AppTypography.jakarta(
                    size: 20,
                    weight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.name,
                      style: AppTypography.jakarta(
                          size: 14.5, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      source.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.jakarta(
                        size: 12,
                        weight: FontWeight.w400,
                        color: AppColors.textFaintestAlt,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: status.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          status.label,
                          style: AppTypography.jakarta(
                            size: 11,
                            weight: FontWeight.w600,
                            color: status.color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSunken,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            source.lang,
                            style: AppTypography.jakarta(
                              size: 10.5,
                              weight: FontWeight.w400,
                              color: AppColors.textFaintest,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(AppIcons.forward,
                  size: 18, color: AppColors.textFaintest),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon button 44×44 r13 bergaya accent-tinted (header Jelajahi).
class _AccentIconButton extends StatelessWidget {
  const _AccentIconButton({
    required this.child,
    required this.onTap,
    this.badgeCount,
  });

  final Widget child;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0x1A1E88C8), // rgba(30,136,200,.1)
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0x591E88C8)), // .35
            ),
            alignment: Alignment.center,
            child: child,
          ),
          if (badgeCount != null)
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16),
                height: 16,
                padding: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$badgeCount',
                  style: AppTypography.jakarta(
                    size: 9.5,
                    weight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Glyph "repository" prototipe: buku + lingkaran dengan plus (viewBox 24).
class RepoGlyphPainter extends CustomPainter {
  const RepoGlyphPainter({required this.color, this.strokeWidth = 2});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // M21 8V6a2 2 0 0 0-2-2H7a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h6
    final book = Path()
      ..moveTo(21 * s, 8 * s)
      ..lineTo(21 * s, 6 * s)
      ..arcToPoint(Offset(19 * s, 4 * s),
          radius: Radius.circular(2 * s), clockwise: false)
      ..lineTo(7 * s, 4 * s)
      ..arcToPoint(Offset(5 * s, 6 * s),
          radius: Radius.circular(2 * s), clockwise: false)
      ..lineTo(5 * s, 18 * s)
      ..arcToPoint(Offset(7 * s, 20 * s),
          radius: Radius.circular(2 * s), clockwise: false)
      ..lineTo(13 * s, 20 * s);
    canvas.drawPath(book, paint);

    canvas.drawLine(Offset(8 * s, 7 * s), Offset(16 * s, 7 * s), paint);
    canvas.drawLine(Offset(8 * s, 11 * s), Offset(13 * s, 11 * s), paint);

    canvas.drawCircle(Offset(18 * s, 17 * s), 4 * s, paint);
    canvas.drawLine(
        Offset(18 * s, 15.5 * s), Offset(18 * s, 18.5 * s), paint);
    canvas.drawLine(
        Offset(16.5 * s, 17 * s), Offset(19.5 * s, 17 * s), paint);
  }

  @override
  bool shouldRepaint(RepoGlyphPainter oldDelegate) =>
      color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
}
