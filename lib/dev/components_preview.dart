// HARNESS DEV SEMENTARA — bukan bagian dari desain.
// Layar ini hanya untuk mereview shared components (15_shared_components.md)
// sebelum layar-layar asli dibangun. Akan dihapus saat 03_onboarding.md
// diimplementasikan dan MaterialApp menunjuk ke alur asli.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/widgets.dart';

class ComponentsPreviewScreen extends StatefulWidget {
  const ComponentsPreviewScreen({super.key});

  @override
  State<ComponentsPreviewScreen> createState() =>
      _ComponentsPreviewScreenState();
}

class _ComponentsPreviewScreenState extends State<ComponentsPreviewScreen> {
  AppTab _tab = AppTab.browse;
  bool _switchOn = true;
  int _segment = 0;
  bool _showEmptyState = false;

  static const _demoCollections = [
    SheetCollection(name: 'Favorit', count: 12, selected: true),
    SheetCollection(name: 'Manhwa', count: 8),
    SheetCollection(name: 'Selesai dibaca', count: 23),
  ];

  static final _demoCover = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      HSLColor.fromAHSL(1, 265, 0.46, 0.26).toColor(),
      HSLColor.fromAHSL(1, 293, 0.58, 0.12).toColor(),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: _showEmptyState
                ? AppEmptyState(
                    icon: const LibraryGlyph(
                        size: 42, color: AppColors.emptyIcon, strokeWidth: 1.7),
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
                        const TextSpan(
                            text: ' untuk mulai membangun library-mu.'),
                      ],
                    ),
                    ctaLabel: 'Jelajahi sumber',
                    onCta: () =>
                        AppToast.show(context, 'CTA empty state ditekan'),
                  )
                : _buildTriggerList(),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: AppBottomNavBackdrop(
              child: AppBottomNav(
                active: _tab,
                onSelect: (t) => setState(() => _tab = t),
              ),
            ),
          ),
          if (_tab == AppTab.browse)
            Positioned(
              right: AppDimens.fabRight,
              bottom: AppDimens.fabBottom,
              child: AppFab(
                onTap: () => AppToast.show(context, 'FAB: tambah sumber'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTriggerList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 160),
      children: [
        Text('PREVIEW KOMPONEN (DEV)', style: AppTypography.eyebrow),
        const SizedBox(height: 14),
        _trigger('Filter/sort sheet', _openFilterSheet),
        _trigger('Context menu — komik', _openComicMenu),
        _trigger('Context menu — sumber', _openSourceMenu),
        _trigger('Reader more menu', _openReaderMenu),
        _trigger('Collection picker', _openCollectionPicker),
        _trigger('Kelola koleksi', _openManageCollections),
        _trigger('Toast', () => AppToast.show(context, 'Disimpan ke Library')),
        _trigger('Empty state (toggle)',
            () => setState(() => _showEmptyState = true)),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Pill switch',
                style: AppTypography.jakarta(size: 13.5, weight: FontWeight.w600)),
            AppPillSwitch(
              value: _switchOn,
              onChanged: (v) => setState(() => _switchOn = v),
            ),
          ],
        ),
        const SizedBox(height: 20),
        AppSegmentedControl(
          items: const [
            AppSegmentItem(label: 'Webtoon', icon: LucideIcons.arrowDown),
            AppSegmentItem(label: 'Halaman', icon: LucideIcons.arrowRight),
            AppSegmentItem(label: 'Manga R→L', icon: LucideIcons.arrowLeft),
          ],
          selectedIndex: _segment,
          onSelect: (i) => setState(() => _segment = i),
        ),
      ],
    );
  }

  Widget _trigger(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusRowSmall),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimens.radiusRowSmall),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: AppTypography.jakarta(
                        size: 13.5, weight: FontWeight.w600)),
              ),
              const Icon(AppIcons.forward,
                  size: 16, color: AppColors.textFaint),
            ],
          ),
        ),
      ),
    );
  }

  void _openFilterSheet() {
    showAppSheet(
      context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSheetTitle('Urutkan koleksi'),
          AppSheetOptionRow(
            label: 'Terakhir dibaca',
            selected: true,
            showTopDivider: false,
            onTap: () => Navigator.pop(sheetContext),
          ),
          AppSheetOptionRow(
            label: 'Judul A–Z',
            selected: false,
            onTap: () => Navigator.pop(sheetContext),
          ),
          AppSheetOptionRow(
            label: 'Belum dibaca terbanyak',
            selected: false,
            onTap: () => Navigator.pop(sheetContext),
          ),
        ],
      ),
    );
  }

  void _openComicMenu() {
    showComicContextMenu(
      context,
      cover: _demoCover,
      title: 'Solo Leveling',
      subtitle: 'MangaVerse · 42 chapter',
      onOpenDetail: () => AppToast.show(context, 'Buka detail'),
      onMoveToCollection: () => AppToast.show(context, 'Pindahkan ke koleksi'),
      onMarkFinished: () => AppToast.show(context, 'Ditandai selesai'),
      onRemoveFromLibrary: () => AppToast.show(context, 'Dihapus dari Library'),
    );
  }

  void _openSourceMenu() {
    showSourceContextMenu(
      context,
      cover: _demoCover,
      title: 'MangaVerse',
      subtitle: 'mangaverse.example.com',
      sourceActive: true,
      onOpenSource: () => AppToast.show(context, 'Buka sumber'),
      onEditSource: () => AppToast.show(context, 'Edit sumber'),
      onToggleSource: () => AppToast.show(context, 'Sumber dinonaktifkan'),
      onRemoveSource: () => AppToast.show(context, 'Sumber dihapus'),
    );
  }

  void _openReaderMenu() {
    showReaderMoreMenu(
      context,
      onOpenComicDetail: () => AppToast.show(context, 'Lihat detail komik'),
      onMarkUnread: () => AppToast.show(context, 'Ditandai belum dibaca'),
      onShareChapter: () => AppToast.show(context, 'Bagikan chapter'),
    );
  }

  void _openCollectionPicker() {
    showCollectionPickerSheet(
      context,
      title: 'Pindahkan ke koleksi',
      collections: _demoCollections,
      onPick: (name) => AppToast.show(context, 'Dipindahkan ke "$name"'),
      onCreateAndPick: (name) =>
          AppToast.show(context, 'Koleksi "$name" dibuat'),
    );
  }

  void _openManageCollections() {
    showManageCollectionsSheet(
      context,
      collections: _demoCollections,
      onDelete: (name) => AppToast.show(context, 'Koleksi "$name" dihapus'),
      onCreate: (name) => AppToast.show(context, 'Koleksi "$name" dibuat'),
    );
  }
}
