import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/demo_state.dart';
import '../../data/library_state.dart';
import '../../data/models.dart';
import '../../data/updates_state.dart';
import '../detail/comic_detail_screen.dart';
import '../home/home_shell.dart';

enum LibrarySort { recent, recentlyAdded, latestUpdate, az, unread }

/// Urutan Library dipisah dari widget supaya aturan tanggal bisa dites tanpa
/// harus membuka sheet. Item lama tanpa `addedAt` tetap di belakang dan urutan
/// relatifnya tidak berubah.
List<Comic> sortLibraryComics(
  List<Comic> comics,
  LibrarySort sort, {
  Map<String, DateTime>? updateTimes,
}) {
  final items = [...comics];
  switch (sort) {
    case LibrarySort.recent:
      break; // Provider mempertahankan urutan "terakhir dibaca" yang aktif.
    case LibrarySort.recentlyAdded:
      final originalIndex = {
        for (var i = 0; i < items.length; i++) items[i].id: i,
      };
      items.sort((a, b) {
        final aDate = a.addedAt;
        final bDate = b.addedAt;
        if (aDate == null && bDate == null) {
          return originalIndex[a.id]!.compareTo(originalIndex[b.id]!);
        }
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        final byDate = bDate.compareTo(aDate);
        return byDate != 0
            ? byDate
            : originalIndex[a.id]!.compareTo(originalIndex[b.id]!);
      });
    case LibrarySort.latestUpdate:
      final originalIndex = {
        for (var i = 0; i < items.length; i++) items[i].id: i,
      };
      items.sort((a, b) {
        final aDate = updateTimes?[a.id] ?? a.addedAt;
        final bDate = updateTimes?[b.id] ?? b.addedAt;
        if (aDate == null && bDate == null) {
          return originalIndex[a.id]!.compareTo(originalIndex[b.id]!);
        }
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        final byDate = bDate.compareTo(aDate);
        return byDate != 0
            ? byDate
            : originalIndex[a.id]!.compareTo(originalIndex[b.id]!);
      });
    case LibrarySort.az:
      items.sort((a, b) => a.title.compareTo(b.title));
    case LibrarySort.unread:
      items.sort((a, b) => b.unread.compareTo(a.unread));
  }
  return items;
}

/// Tab Library — spek 04.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String? _activeTab;
  bool _searchOpen = false;
  String _query = '';
  LibrarySort _sort = LibrarySort.recent;
  final _searchController = TextEditingController();
  late final PageController _pageController;
  final ScrollController _chipScrollController = ScrollController();
  bool _selectionMode = false;
  final Set<String> _selectedComicIds = {};
  String? _sourceFilter;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    _chipScrollController.dispose();
    super.dispose();
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedComicIds.clear();
    });
  }

  void _toggleSelection(String comicId) {
    setState(() {
      if (_selectedComicIds.contains(comicId)) {
        _selectedComicIds.remove(comicId);
      } else {
        _selectedComicIds.add(comicId);
      }
    });
  }

  void _toggleSelectAll(List<Comic> visible) {
    setState(() {
      if (_selectedComicIds.length == visible.length) {
        _selectedComicIds.clear();
      } else {
        _selectedComicIds.addAll(visible.map((c) => c.id));
      }
    });
  }

  void _selectTab(int index, String collectionId) {
    if (_activeTab == collectionId) return;
    setState(() => _activeTab = collectionId);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
    _scrollToActiveChip(index);
  }

  void _onPageChanged(int index, List<ComicCollection> collections) {
    if (index >= 0 && index < collections.length) {
      final newId = collections[index].id;
      if (_activeTab != newId) {
        setState(() => _activeTab = newId);
        _scrollToActiveChip(index);
      }
    }
  }

  void _scrollToActiveChip(int index) {
    if (!_chipScrollController.hasClients) return;
    final targetOffset = (index * 92.0) - 36.0;
    _chipScrollController.animateTo(
      targetOffset.clamp(0.0, _chipScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  List<Comic> _comicsForCollection(
    List<Comic> library,
    String? collectionId,
    Map<String, DateTime> updateTimes,
  ) {
    final q = _query.trim().toLowerCase();
    var items = library
        .where((c) => q.isEmpty || c.title.toLowerCase().contains(q))
        .toList();
    if (collectionId != null) {
      items = items.where((c) => c.col == collectionId).toList();
    }
    if (_sourceFilter != null) {
      items = items
          .where(
            (c) =>
                c.src.trim().toLowerCase() ==
                _sourceFilter!.trim().toLowerCase(),
          )
          .toList();
    }
    return sortLibraryComics(items, _sort, updateTimes: updateTimes);
  }

  @override
  Widget build(BuildContext context) {
    final demoEmpty = ref.watch(demoLibEmptyProvider);
    final library = demoEmpty ? const <Comic>[] : ref.watch(libraryProvider);
    final collections = ref.watch(collectionsProvider);
    final updates = ref.watch(updatesProvider);
    final updateTimes = {for (final u in updates) u.comicId: u.detectedAt};

    if ((_activeTab == null ||
            _activeTab == 'all' ||
            !collections.any((c) => c.id == _activeTab)) &&
        collections.isNotEmpty) {
      _activeTab = collections.first.id;
    }

    final activeIndex = collections.indexWhere((c) => c.id == _activeTab);
    if (activeIndex >= 0 &&
        _pageController.hasClients &&
        !_pageController.position.isScrollingNotifier.value &&
        _pageController.page?.round() != activeIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        if (!_pageController.position.isScrollingNotifier.value &&
            _pageController.page?.round() != activeIndex) {
          _pageController.jumpToPage(activeIndex);
        }
      });
    }

    final visible = _comicsForCollection(library, _activeTab, updateTimes);
    final libraryEmpty = library.isEmpty;

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: _selectionMode
                    ? Row(
                        children: [
                          AppHeaderIconButton(
                            icon: LucideIcons.x,
                            onTap: _exitSelectionMode,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${_selectedComicIds.length} dipilih',
                              style: AppTypography.screenTitle,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _toggleSelectAll(visible),
                            icon: Icon(
                              _selectedComicIds.length == visible.length &&
                                      visible.isNotEmpty
                                  ? LucideIcons.checkCheck
                                  : LucideIcons.checkSquare,
                              size: 16,
                              color: AppColors.accentText,
                            ),
                            label: Text(
                              _selectedComicIds.length == visible.length &&
                                      visible.isNotEmpty
                                  ? 'Batal Semua'
                                  : 'Pilih Semua',
                              style: AppTypography.jakarta(
                                size: 12.5,
                                weight: FontWeight.w700,
                                color: AppColors.accentText,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
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
                            icon: LucideIcons.globe,
                            onTap: () => _openSourcesManagementSheet(library),
                          ),
                          const SizedBox(width: 6),
                          AppHeaderIconButton(
                            icon: LucideIcons.listFilter,
                            onTap: _openSortSheet,
                          ),
                          const SizedBox(width: 6),
                          AppHeaderIconButton(
                            icon: LucideIcons.checkSquare,
                            onTap: () => setState(() => _selectionMode = true),
                          ),
                        ],
                      ),
              ),
              if (_searchOpen && !_selectionMode)
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
              if (_sourceFilter case final sourceName?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.only(left: 12, right: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.globe,
                          size: 16,
                          color: AppColors.accentText,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Sumber: $sourceName',
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
                          icon: const Icon(LucideIcons.x, size: 16),
                          color: AppColors.textSecondary,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Hapus filter sumber',
                          onPressed: () => setState(() => _sourceFilter = null),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!libraryEmpty)
                SizedBox(
                  height: 46,
                  child: ListView(
                    controller: _chipScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
                    children: [
                      for (var i = 0; i < collections.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        _chip(
                          name: collections[i].name,
                          count: library
                              .where((c) => c.col == collections[i].id)
                              .length,
                          active: _activeTab == collections[i].id,
                          onTap: () => _selectTab(i, collections[i].id),
                        ),
                      ],
                      const SizedBox(width: 8),
                      _AddCollectionChip(onTap: _openManageCollections),
                    ],
                  ),
                ),
              Expanded(
                child: libraryEmpty
                    ? _buildEmptyState()
                    : (collections.isEmpty
                        ? _buildGrid(visible)
                        : PageView.builder(
                            controller: _pageController,
                            physics: _selectionMode
                                ? const NeverScrollableScrollPhysics()
                                : const PageScrollPhysics(),
                            itemCount: collections.length,
                            onPageChanged: (i) =>
                                _onPageChanged(i, collections),
                            itemBuilder: (context, i) {
                              final colComics = _comicsForCollection(
                                library,
                                collections[i].id,
                                updateTimes,
                              );
                              return _buildGrid(colComics);
                            },
                          )),
              ),
            ],
          ),
          if (_selectionMode)
            Positioned(
              right: 18,
              bottom: math.max(
                136.0,
                64.0 +
                    math.max(
                      AppDimens.navMargin.bottom,
                      MediaQuery.paddingOf(context).bottom,
                    ) +
                    32.0,
              ),
              child: _buildFloatingSelectionAction(context, collections),
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
      itemBuilder: (context, i) {
        final comic = visible[i];
        return ComicGridCard(
          key: ValueKey(comic.id),
          comic: comic,
          selected: _selectedComicIds.contains(comic.id),
          selectionMode: _selectionMode,
          onTap: () {
            if (_selectionMode) {
              _toggleSelection(comic.id);
            } else {
              _openDetail(comic);
            }
          },
          onLongPress: () {
            if (_selectionMode) {
              _toggleSelection(comic.id);
            } else {
              _openComicMenu(comic);
            }
          },
        );
      },
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
            label: 'Pembaruan terakhir',
            selected: _sort == LibrarySort.latestUpdate,
            onTap: () => _pickSort(sheetContext, LibrarySort.latestUpdate),
          ),
          AppSheetOptionRow(
            label: 'Terakhir ditambahkan',
            selected: _sort == LibrarySort.recentlyAdded,
            onTap: () => _pickSort(sheetContext, LibrarySort.recentlyAdded),
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
        LibrarySort.latestUpdate => 'Pembaruan terakhir',
        LibrarySort.recentlyAdded => 'Terakhir ditambahkan',
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
      onSelectMultiple: () {
        setState(() {
          _selectionMode = true;
          _selectedComicIds.add(comic.id);
        });
      },
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
        if (_activeTab == id) {
          final remaining =
              ref.read(collectionsProvider).where((c) => c.id != id).toList();
          setState(() {
            _activeTab = remaining.isNotEmpty ? remaining.first.id : null;
          });
        }
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

  Widget _buildFloatingSelectionAction(
    BuildContext context,
    List<ComicCollection> collections,
  ) {
    final count = _selectedComicIds.length;
    final hasSelection = count > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (!hasSelection) {
            AppToast.show(context, 'Pilih komik terlebih dahulu');
            return;
          }
          _showSelectionActionSheet(context, collections);
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: hasSelection
                ? const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                  )
                : const LinearGradient(
                    colors: [Color(0xFF262C38), Color(0xFF1E232D)],
                  ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: hasSelection
                  ? const Color(0xFF60A5FA).withValues(alpha: 0.6)
                  : const Color(0xFF3F4856),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: hasSelection
                    ? const Color(0xFF2563EB).withValues(alpha: 0.45)
                    : Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasSelection
                    ? LucideIcons.slidersHorizontal
                    : LucideIcons.mousePointerClick,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                hasSelection ? '$count Dipilih' : 'Pilih Komik',
                style: AppTypography.jakarta(
                  size: 13,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  LucideIcons.chevronUp,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSelectionActionSheet(
    BuildContext context,
    List<ComicCollection> collections,
  ) {
    final count = _selectedComicIds.length;
    showAppSheet<void>(
      context,
      builder: (sheetContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      LucideIcons.checkSquare,
                      size: 20,
                      color: AppColors.accentText,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$count Komik Dipilih',
                          style: AppTypography.jakarta(
                            size: 16,
                            weight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Pilih tindakan untuk komik yang dipilih',
                          style: AppTypography.jakarta(
                            size: 12,
                            weight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0x1FFFFFFF), height: 16),
            _actionSheetTile(
              icon: LucideIcons.folderInput,
              iconColor: AppColors.accentText,
              iconBg: AppColors.accent.withValues(alpha: 0.15),
              title: 'Pindahkan ke Koleksi Lain',
              subtitle: 'Pindahkan $count komik ke koleksi bacaan lain',
              onTap: () {
                Navigator.pop(sheetContext);
                _batchMoveToCollection(collections);
              },
            ),
            _actionSheetTile(
              icon: LucideIcons.checkCheck,
              iconColor: const Color(0xFF10B981),
              iconBg: const Color(0xFF10B981).withValues(alpha: 0.15),
              title: 'Tandai Selesai Dibaca',
              subtitle: 'Tandai $count komik sebagai sudah tamat',
              onTap: () {
                Navigator.pop(sheetContext);
                _batchMarkFinished();
              },
            ),
            _actionSheetTile(
              icon: LucideIcons.trash2,
              iconColor: AppColors.danger,
              iconBg: AppColors.danger.withValues(alpha: 0.15),
              title: 'Hapus dari Library',
              subtitle: 'Hapus $count komik dari daftar koleksi',
              onTap: () {
                Navigator.pop(sheetContext);
                _batchDelete();
              },
            ),
            _actionSheetTile(
              icon: LucideIcons.x,
              iconColor: AppColors.textSecondary,
              iconBg: AppColors.surfaceAlt,
              title: 'Batal & Selesai',
              subtitle: 'Keluar dari mode pilih banyak',
              onTap: () {
                Navigator.pop(sheetContext);
                _exitSelectionMode();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _actionSheetTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 19, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.jakarta(
                      size: 14,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.jakarta(
                      size: 11.5,
                      weight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  void _batchMoveToCollection(
    List<ComicCollection> collections,
  ) {
    final library = ref.read(libraryProvider);
    showCollectionPickerSheet(
      context,
      title: 'Pindahkan ${_selectedComicIds.length} komik',
      collections: [
        for (final col in collections)
          SheetCollection(
            id: col.id,
            name: col.name,
            count: library.where((c) => c.col == col.id).length,
          ),
      ],
      onPick: (id) {
        final count = _selectedComicIds.length;
        ref
            .read(libraryProvider.notifier)
            .moveToCollectionBatch(_selectedComicIds, id);
        AppToast.show(context, '$count komik dipindahkan');
        _exitSelectionMode();
      },
      onCreateAndPick: (name) async {
        final id = await ref.read(collectionsProvider.notifier).create(name);
        final count = _selectedComicIds.length;
        if (mounted) {
          await ref
              .read(libraryProvider.notifier)
              .moveToCollectionBatch(_selectedComicIds, id);
          if (mounted) {
            AppToast.show(context, '$count komik dipindahkan ke $name');
            _exitSelectionMode();
          }
        }
      },
    );
  }

  Future<void> _batchDelete() async {
    final count = _selectedComicIds.length;
    if (count == 0) return;
    final confirmed = await showConfirmSheet(
      context,
      title: 'Hapus $count Komik?',
      message:
          '$count komik yang dipilih akan dihapus dari Library. '
          'Riwayat baca tidak ikut terhapus.',
    );
    if (confirmed && mounted) {
      await ref.read(libraryProvider.notifier).removeBatch(_selectedComicIds);
      if (mounted) {
        AppToast.show(context, '$count komik dihapus dari Library');
        _exitSelectionMode();
      }
    }
  }

  Future<void> _batchMarkFinished() async {
    final count = _selectedComicIds.length;
    if (count == 0) return;
    for (final id in _selectedComicIds) {
      await ref.read(libraryProvider.notifier).markFinished(id);
    }
    if (!mounted) return;
    AppToast.show(context, '$count komik ditandai selesai');
    _exitSelectionMode();
  }

  void _openSourcesManagementSheet(List<Comic> library) {
    final grouped = groupComicsBySource(library);
    final sortedSources = grouped.keys.toList()
      ..sort((a, b) => grouped[b]!.length.compareTo(grouped[a]!.length));

    showAppSheet<void>(
      context,
      builder: (sheetContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSheetTitle('Kelola Berdasarkan Sumber', bottomGap: 14),
            if (sortedSources.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Belum ada komik di Library',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.6,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sortedSources.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    color: Color(0x1FFFFFFF),
                  ),
                  itemBuilder: (itemCtx, i) {
                    final sourceName = sortedSources[i];
                    final comics = grouped[sourceName]!;
                    final isCurrentFilter = _sourceFilter != null &&
                        _sourceFilter!.toLowerCase() ==
                            sourceName.toLowerCase();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              LucideIcons.globe,
                              size: 18,
                              color: AppColors.accentText,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sourceName,
                                  style: AppTypography.jakarta(
                                    size: 14,
                                    weight: FontWeight.w700,
                                    color: isCurrentFilter
                                        ? AppColors.accentText
                                        : Colors.white,
                                  ),
                                ),
                                Text(
                                  '${comics.length} komik tersimpan',
                                  style: AppTypography.jakarta(
                                    size: 12,
                                    weight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: isCurrentFilter
                                ? 'Hapus filter'
                                : 'Filter komik sumber ini',
                            icon: Icon(
                              isCurrentFilter
                                  ? LucideIcons.filterX
                                  : LucideIcons.filter,
                              size: 18,
                              color: isCurrentFilter
                                  ? AppColors.accentText
                                  : AppColors.textSecondary,
                            ),
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              setState(() {
                                _sourceFilter =
                                    isCurrentFilter ? null : sourceName;
                              });
                              AppToast.show(
                                context,
                                isCurrentFilter
                                    ? 'Filter sumber dibersihkan'
                                    : 'Filter: $sourceName',
                              );
                            },
                          ),
                          IconButton(
                            tooltip: 'Pilih semua komik sumber ini',
                            icon: const Icon(LucideIcons.checkSquare, size: 18),
                            color: AppColors.textSecondary,
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              setState(() {
                                _selectionMode = true;
                                _selectedComicIds.addAll(
                                  comics.map((c) => c.id),
                                );
                              });
                              AppToast.show(
                                context,
                                '${comics.length} komik dari $sourceName dipilih',
                              );
                            },
                          ),
                          IconButton(
                            tooltip: 'Hapus semua komik dari sumber ini',
                            icon: const Icon(LucideIcons.trash2, size: 18),
                            color: AppColors.danger,
                            onPressed: () async {
                              Navigator.pop(sheetContext);
                              final confirmed = await showConfirmSheet(
                                context,
                                title: 'Hapus Semua Komik?',
                                message:
                                    'Hapus semua ${comics.length} komik dari "$sourceName"? '
                                    'Komik dari sumber lain tidak terpengaruh.',
                              );
                              if (confirmed && mounted) {
                                await ref
                                    .read(libraryProvider.notifier)
                                    .removeBySource(sourceName);
                                if (mounted) {
                                  AppToast.show(
                                    context,
                                    'Semua komik $sourceName dihapus',
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        );
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
    this.selected = false,
    this.selectionMode = false,
  });

  final Comic comic;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Override caption bawah (default "Ch. N").
  final String? caption;
  final bool selected;
  final bool selectionMode;

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
                  border: selected
                      ? Border.all(color: AppColors.accent, width: 2.2)
                      : null,
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
                    if (selectionMode)
                      Positioned.fill(
                        child: Container(
                          color: selected
                              ? AppColors.accent.withValues(alpha: 0.28)
                              : Colors.black.withValues(alpha: 0.25),
                        ),
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
                    if (comic.unread > 0 && !selectionMode)
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
                    if (selectionMode)
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.accent
                                : const Color(0xB3000000),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected ? Colors.white : Colors.white70,
                              width: 2,
                            ),
                          ),
                          child: selected
                              ? const Icon(
                                  LucideIcons.check,
                                  size: 13,
                                  color: Colors.white,
                                )
                              : null,
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
