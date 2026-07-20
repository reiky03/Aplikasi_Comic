import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/demo_state.dart';
import '../../data/library_state.dart';
import '../../data/models.dart';
import '../detail/comic_detail_screen.dart';
import '../home/home_shell.dart';

enum LibrarySort { recent, az, unread }

/// Tab Library — spek 04.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String _activeTab = 'all';
  bool _searchOpen = false;
  String _query = '';
  LibrarySort _sort = LibrarySort.recent;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Comic> _visibleComics(List<Comic> library) {
    final q = _query.trim().toLowerCase();
    var items = library
        .where((c) => q.isEmpty || c.title.toLowerCase().contains(q))
        .toList();
    if (_activeTab != 'all') {
      items = items.where((c) => c.col == _activeTab).toList();
    }
    switch (_sort) {
      case LibrarySort.recent:
        break; // urutan library = urutan "terakhir dibaca" (prototipe)
      case LibrarySort.az:
        items.sort((a, b) => a.title.compareTo(b.title));
      case LibrarySort.unread:
        items.sort((a, b) => b.unread.compareTo(a.unread));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final demoEmpty = ref.watch(demoLibEmptyProvider);
    final library = demoEmpty ? const <Comic>[] : ref.watch(libraryProvider);
    final collections = ref.watch(collectionsProvider);
    final visible = _visibleComics(library);
    final libraryEmpty = library.isEmpty;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text('Library', style: AppTypography.screenTitle),
                ),
                AppHeaderIconButton(
                  icon: AppIcons.search,
                  onTap: () => setState(() {
                    _searchOpen = !_searchOpen;
                    if (!_searchOpen) {
                      _query = '';
                      _searchController.clear();
                    }
                  }),
                ),
                const SizedBox(width: 6),
                AppHeaderIconButton(
                  icon: LucideIcons.listFilter,
                  onTap: _openSortSheet,
                ),
              ],
            ),
          ),
          if (_searchOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: _SearchField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                onClose: () => setState(() {
                  _searchOpen = false;
                  _query = '';
                  _searchController.clear();
                }),
              ),
            ),
          if (!libraryEmpty)
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
                children: [
                  _chip(
                    name: 'Semua',
                    count: library.length,
                    active: _activeTab == 'all',
                    onTap: () => setState(() => _activeTab = 'all'),
                  ),
                  for (final col in collections) ...[
                    const SizedBox(width: 8),
                    _chip(
                      name: col.name,
                      count: library.where((c) => c.col == col.id).length,
                      active: _activeTab == col.id,
                      onTap: () => setState(() => _activeTab = col.id),
                    ),
                  ],
                  const SizedBox(width: 8),
                  _AddCollectionChip(onTap: _openManageCollections),
                ],
              ),
            ),
          Expanded(
            child: libraryEmpty ? _buildEmptyState() : _buildGrid(visible),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String name,
    required int count,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: active ? AppColors.accent : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          children: [
            Text(
              name,
              style: AppTypography.jakarta(
                size: 12.5,
                weight: FontWeight.w700,
                color: active ? Colors.white : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 7),
            Container(
              constraints: const BoxConstraints(minWidth: 18),
              height: 18,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Text(
                '$count',
                style: AppTypography.jakarta(
                  size: 10.5,
                  weight: FontWeight.w800,
                  color: active ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(List<Comic> visible) {
    if (visible.isEmpty) {
      final searching = _query.trim().isNotEmpty;
      return _InlineEmptyMessage(
        title: searching ? 'Tidak ada hasil' : 'Belum ada komik di koleksi ini',
        subtitle: searching
            ? 'Coba kata kunci lain.'
            : 'Pindahkan komik ke koleksi ini lewat menu tahan-lama.',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: AppDimens.gridColumns,
        crossAxisSpacing: AppDimens.gridGap,
        mainAxisSpacing: AppDimens.gridGap,
        // cover 2:3 + judul 2 baris + caption
        childAspectRatio: 0.475,
      ),
      itemCount: visible.length,
      itemBuilder: (context, i) => ComicGridCard(
        key: ValueKey(visible[i].id),
        comic: visible[i],
        onTap: () => _openDetail(visible[i]),
        onLongPress: () => _openComicMenu(visible[i]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return AppEmptyState(
      icon: const LibraryGlyph(
        size: 42,
        color: AppColors.emptyIcon,
        strokeWidth: 1.7,
      ),
      title: 'Belum ada komik di koleksi',
      description: TextSpan(
        children: [
          const TextSpan(text: 'Tambahkan komik dari menu '),
          TextSpan(
            text: 'Jelajahi',
            style: AppTypography.jakarta(
              size: 13.5,
              weight: FontWeight.w600,
              color: AppColors.accentText,
            ),
          ),
          const TextSpan(text: ' untuk mulai membangun library-mu.'),
        ],
      ),
      ctaLabel: 'Jelajahi sumber',
      onCta: () => ref.read(activeTabProvider.notifier).set(AppTab.browse),
    );
  }

  void _openDetail(Comic comic) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ComicDetailScreen(comic: comic)),
    );
  }

  void _openSortSheet() {
    showAppSheet<void>(
      context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSheetTitle('Urutkan koleksi'),
          AppSheetOptionRow(
            label: 'Terakhir dibaca',
            selected: _sort == LibrarySort.recent,
            showTopDivider: false,
            onTap: () => _pickSort(sheetContext, LibrarySort.recent),
          ),
          AppSheetOptionRow(
            label: 'Judul A–Z',
            selected: _sort == LibrarySort.az,
            onTap: () => _pickSort(sheetContext, LibrarySort.az),
          ),
          AppSheetOptionRow(
            label: 'Belum dibaca terbanyak',
            selected: _sort == LibrarySort.unread,
            onTap: () => _pickSort(sheetContext, LibrarySort.unread),
          ),
        ],
      ),
    );
  }

  void _pickSort(BuildContext sheetContext, LibrarySort sort) {
    Navigator.pop(sheetContext);
    setState(() => _sort = sort);
    AppToast.show(
      context,
      'Diurutkan: ${switch (sort) {
        LibrarySort.recent => 'Terakhir dibaca',
        LibrarySort.az => 'Judul A–Z',
        LibrarySort.unread => 'Belum dibaca',
      }}',
    );
  }

  void _openComicMenu(Comic comic) {
    showComicContextMenu(
      context,
      cover: comicCover(comic.hue),
      title: comic.title,
      subtitle: '${comic.src} · ${comic.ch} chapter',
      onOpenDetail: () => _openDetail(comic),
      onMoveToCollection: () => _openCollectionPicker(comic),
      onMarkFinished: () {
        ref.read(libraryProvider.notifier).markFinished(comic.id);
        AppToast.show(context, 'Ditandai selesai');
      },
      onRemoveFromLibrary: () {
        ref.read(libraryProvider.notifier).remove(comic.id);
        AppToast.show(context, 'Dihapus dari Library');
      },
    );
  }

  void _openCollectionPicker(Comic comic) {
    final collections = ref.read(collectionsProvider);
    final library = ref.read(libraryProvider);
    showCollectionPickerSheet(
      context,
      title: 'Pindahkan ke koleksi',
      collections: [
        for (final col in collections)
          SheetCollection(
            id: col.id,
            name: col.name,
            count: library.where((c) => c.col == col.id).length,
            selected: comic.col == col.id,
          ),
      ],
      onPick: (id) {
        ref.read(libraryProvider.notifier).moveToCollection(comic.id, id);
        AppToast.show(context, 'Dipindahkan koleksi');
      },
      onCreateAndPick: (name) async {
        final id = await ref.read(collectionsProvider.notifier).create(name);
        ref.read(libraryProvider.notifier).moveToCollection(comic.id, id);
        if (mounted) AppToast.show(context, 'Ditambahkan ke $name');
      },
      onRemove: () async {
        await ref.read(libraryProvider.notifier).remove(comic.id);
        if (mounted) AppToast.show(context, 'Penyimpanan komik dibatalkan');
      },
    );
  }

  void _openManageCollections() {
    final collections = ref.read(collectionsProvider);
    final library = ref.read(libraryProvider);
    showManageCollectionsSheet(
      context,
      collections: [
        for (final col in collections)
          SheetCollection(
            id: col.id,
            name: col.name,
            count: library.where((c) => c.col == col.id).length,
          ),
      ],
      onDelete: (id) {
        ref.read(collectionsProvider.notifier).delete(id);
        if (_activeTab == id) setState(() => _activeTab = 'all');
        AppToast.show(context, 'Koleksi dihapus');
      },
      onCreate: (name) async {
        final id = await ref.read(collectionsProvider.notifier).create(name);
        if (mounted) AppToast.show(context, 'Koleksi "$name" dibuat');
        return id;
      },
      onRename: (id, newName) {
        ref.read(collectionsProvider.notifier).rename(id, newName);
        AppToast.show(context, 'Koleksi diganti jadi "$newName"');
      },
    );
  }
}

/// Kartu cover komik untuk grid 3 kolom (dipakai Library & discover grid).
class ComicGridCard extends StatelessWidget {
  const ComicGridCard({
    super.key,
    required this.comic,
    required this.onTap,
    this.onLongPress,
    this.caption,
  });

  final Comic comic;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Override caption bawah (default "Ch. N").
  final String? caption;

  @override
  Widget build(BuildContext context) {
    // Lebar sel grid nyata (3 kolom, padding 18 kiri/kanan, gap antar sel)
    // — dipakai buat `cacheWidth` di bawah, biar Image.network DECODE pas
    // ukuran tampil (bukan resolusi asli cover yang bisa jauh lebih besar),
    // jauh lebih ringan buat GPU/memory pas banyak kartu di-scroll sekaligus.
    final cellWidth =
        (MediaQuery.sizeOf(context).width -
            36 -
            AppDimens.gridGap * (AppDimens.gridColumns - 1)) /
        AppDimens.gridColumns;
    final cacheWidth = (cellWidth * MediaQuery.devicePixelRatioOf(context))
        .round();
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: AppDimens.coverAspectRatio,
            // Isolasi jadi layer sendiri — pas scroll, kartu yang sudah
            // dirender tinggal di-translate (murah), bukan di-rasterisasi
            // ulang tiap frame (gradient + shadow + gambar bakal lumayan
            // berat kalau diulang terus buat semua kartu yang kelihatan).
            child: RepaintBoundary(
              child: Container(
                decoration: BoxDecoration(
                  gradient: comicCover(comic.hue),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x99000000),
                      offset: Offset(0, 6),
                      blurRadius: 16,
                      spreadRadius: -6,
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    comicCoverContent(
                      coverUrl: comic.coverUrl,
                      headers: comic.coverHeaders,
                      initial: comic.initial,
                      cacheWidth: cacheWidth,
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: 44,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Color(0xB3000000), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    if (comic.unread > 0)
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 20),
                          height: 20,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: AppColors.badge,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x66000000),
                                offset: Offset(0, 3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${comic.unread}',
                            style: AppTypography.jakarta(
                              size: 11,
                              weight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            comic.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.jakarta(
              size: 12,
              weight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption ?? comic.lastLabel,
            style: AppTypography.jakarta(
              size: 10.5,
              weight: FontWeight.w400,
              color: AppColors.textFaintestAlt,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClose,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x591E88C8)), // accent .35
      ),
      child: Row(
        children: [
          const Icon(AppIcons.search, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              autofocus: true,
              cursorColor: AppColors.accent,
              style: AppTypography.jakarta(size: 14, weight: FontWeight.w400),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Cari di library…',
                hintStyle: AppTypography.jakarta(
                  size: 14,
                  weight: FontWeight.w400,
                  color: AppColors.textFaint,
                ),
              ),
            ),
          ),
          InkWell(
            onTap: onClose,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(AppIcons.close, size: 16, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip "+" dashed di ujung row koleksi → Kelola koleksi.
class _AddCollectionChip extends StatelessWidget {
  const _AddCollectionChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: SizedBox(
        width: 34,
        height: 34,
        child: CustomPaint(
          painter: const _DashedCirclePainter(
            color: Color(0x2EFFFFFF), // rgba(255,255,255,.18)
          ),
          child: const Icon(
            AppIcons.add,
            size: 16,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rect = (Offset.zero & size).deflate(0.5);
    const dashCount = 14;
    const sweep = 3.1415926535 * 2 / dashCount;
    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter oldDelegate) =>
      color != oldDelegate.color;
}

/// Pesan kosong ringan (hasil pencarian kosong / koleksi kosong).
class _InlineEmptyMessage extends StatelessWidget {
  const _InlineEmptyMessage({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 60, 30, 0),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.jakarta(
              size: 14,
              weight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTypography.jakarta(
              size: 12.5,
              weight: FontWeight.w400,
              color: AppColors.textFaint,
            ),
          ),
        ],
      ),
    );
  }
}
