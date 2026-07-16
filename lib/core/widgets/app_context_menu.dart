import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';
import 'app_sheet.dart';

/// Row preview di atas context menu: cover 42×42 r11 + judul + subjudul.
class ContextMenuPreview extends StatelessWidget {
  const ContextMenuPreview({
    super.key,
    required this.cover,
    required this.title,
    required this.subtitle,
  });

  /// Gradient placeholder cover (atau warna solid).
  final Gradient cover;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: cover,
              borderRadius: BorderRadius.circular(11),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.rowTitleLarge,
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.jakarta(
                    size: 11.5,
                    weight: FontWeight.w400,
                    color: AppColors.textFaintestAlt,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Context menu long-press komik (Library) — spek 15.
Future<void> showComicContextMenu(
  BuildContext context, {
  required Gradient cover,
  required String title,
  required String subtitle,
  required VoidCallback onOpenDetail,
  required VoidCallback onMoveToCollection,
  required VoidCallback onMarkFinished,
  required VoidCallback onRemoveFromLibrary,
}) {
  return showAppSheet(
    context,
    menuStyle: true,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ContextMenuPreview(cover: cover, title: title, subtitle: subtitle),
        AppSheetMenuRow(
          icon: LucideIcons.eye,
          label: 'Buka detail',
          onTap: () {
            Navigator.pop(sheetContext);
            onOpenDetail();
          },
        ),
        AppSheetMenuRow(
          icon: LucideIcons.folder,
          label: 'Pindahkan ke koleksi',
          onTap: () {
            Navigator.pop(sheetContext);
            onMoveToCollection();
          },
        ),
        AppSheetMenuRow(
          icon: LucideIcons.circleCheckBig,
          iconColor: AppColors.success,
          label: 'Tandai selesai',
          onTap: () {
            Navigator.pop(sheetContext);
            onMarkFinished();
          },
        ),
        AppSheetMenuRow(
          icon: AppIcons.delete,
          label: 'Hapus dari Library',
          destructive: true,
          onTap: () {
            Navigator.pop(sheetContext);
            onRemoveFromLibrary();
          },
        ),
      ],
    ),
  );
}

/// Context menu long-press sumber (Jelajahi → Sumber Saya) — spek 15.
Future<void> showSourceContextMenu(
  BuildContext context, {
  required Gradient cover,
  required String title,
  required String subtitle,
  required bool sourceActive,
  required VoidCallback onOpenSource,
  required VoidCallback onEditSource,
  required VoidCallback onToggleSource,
  required VoidCallback onRemoveSource,
}) {
  return showAppSheet(
    context,
    menuStyle: true,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ContextMenuPreview(cover: cover, title: title, subtitle: subtitle),
        AppSheetMenuRow(
          icon: AppIcons.browse,
          label: 'Buka sumber',
          onTap: () {
            Navigator.pop(sheetContext);
            onOpenSource();
          },
        ),
        AppSheetMenuRow(
          icon: AppIcons.edit,
          label: 'Edit sumber',
          onTap: () {
            Navigator.pop(sheetContext);
            onEditSource();
          },
        ),
        AppSheetMenuRow(
          icon: LucideIcons.power,
          label: sourceActive ? 'Nonaktifkan sumber' : 'Aktifkan sumber',
          onTap: () {
            Navigator.pop(sheetContext);
            onToggleSource();
          },
        ),
        AppSheetMenuRow(
          icon: AppIcons.delete,
          label: 'Hapus sumber',
          destructive: true,
          onTap: () {
            Navigator.pop(sheetContext);
            onRemoveSource();
          },
        ),
      ],
    ),
  );
}

/// Menu "more" di Reader — tanpa preview row.
Future<void> showReaderMoreMenu(
  BuildContext context, {
  required VoidCallback onOpenComicDetail,
  required VoidCallback onMarkUnread,
  required VoidCallback onShareChapter,
  required VoidCallback onViewBookmarks,
}) {
  return showAppSheet(
    context,
    menuStyle: true,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSheetMenuRow(
          icon: LucideIcons.book,
          label: 'Lihat detail komik',
          onTap: () {
            Navigator.pop(sheetContext);
            onOpenComicDetail();
          },
        ),
        AppSheetMenuRow(
          icon: LucideIcons.bookmark,
          label: 'Lihat bookmark',
          onTap: () {
            Navigator.pop(sheetContext);
            onViewBookmarks();
          },
        ),
        AppSheetMenuRow(
          icon: AppIcons.errorCircle,
          label: 'Tandai belum dibaca',
          onTap: () {
            Navigator.pop(sheetContext);
            onMarkUnread();
          },
        ),
        AppSheetMenuRow(
          icon: LucideIcons.share,
          label: 'Bagikan chapter',
          onTap: () {
            Navigator.pop(sheetContext);
            onShareChapter();
          },
        ),
      ],
    ),
  );
}

/// Sheet daftar bookmark satu komik (dipanggil dari Reader more-menu) —
/// tiap baris: label chapter + halaman + waktu ditandai, tap = lompat ke
/// situ, tombol hapus di kanan.
Future<void> showBookmarkListSheet(
  BuildContext context, {
  required List<BookmarkListItem> items,
  required ValueChanged<BookmarkListItem> onTapItem,
  required ValueChanged<BookmarkListItem> onRemoveItem,
}) {
  return showAppSheet(
    context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSheetTitle('Bookmark'),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Belum ada bookmark di komik ini.\nTandai halaman lewat '
                  'ikon bookmark saat baca.',
                  textAlign: TextAlign.center,
                  style: AppTypography.jakarta(
                    size: 13,
                    weight: FontWeight.w400,
                    height: 1.5,
                    color: AppColors.textMuted,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return InkWell(
                      onTap: () {
                        Navigator.pop(sheetContext);
                        onTapItem(item);
                      },
                      child: Container(
                        decoration: i == 0
                            ? null
                            : const BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                      color: AppColors.sheetRowDivider),
                                ),
                              ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 4),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.bookmark,
                                size: 17, color: AppColors.accentText),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.chapterLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.jakarta(
                                        size: 13.5, weight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Hal ${item.page}/${item.pages}',
                                    style: AppTypography.jakarta(
                                      size: 12,
                                      weight: FontWeight.w400,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setSheetState(() => items.remove(item));
                                onRemoveItem(item);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(AppIcons.delete,
                                    size: 16, color: AppColors.menuIcon),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    ),
  );
}

/// Data ringkas satu baris di [showBookmarkListSheet] — dipisah dari
/// `BookmarkEntry` (lib/data/bookmarks_state.dart) supaya widget ini tidak
/// perlu tahu skema data/Firestore-nya.
class BookmarkListItem {
  const BookmarkListItem({
    required this.id,
    required this.chNum,
    required this.chapterLabel,
    required this.page,
    required this.pages,
  });

  final String id;
  final int chNum;
  final String chapterLabel;
  final int page;
  final int pages;
}
