import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';
import 'app_sheet.dart';

/// Data koleksi untuk sheet (UI murni; wiring state di layar pemanggil).
class SheetCollection {
  const SheetCollection({
    required this.name,
    required this.count,
    this.selected = false,
  });

  final String name;
  final int count;

  /// Koleksi yang sedang ter-assign (tampilkan checkmark saat "memindahkan").
  final bool selected;
}

/// Collection picker — spek 15. Judul kontekstual:
/// "Simpan ke koleksi" (belum di Library) vs "Pindahkan ke koleksi".
/// Tap row langsung commit + tutup; "Buat koleksi baru" expand jadi input.
Future<void> showCollectionPickerSheet(
  BuildContext context, {
  required String title,
  required List<SheetCollection> collections,
  required ValueChanged<String> onPick,
  required ValueChanged<String> onCreateAndPick,
}) {
  return showAppSheet(
    context,
    builder: (sheetContext) => _CollectionPickerBody(
      title: title,
      collections: collections,
      onPick: onPick,
      onCreateAndPick: onCreateAndPick,
    ),
  );
}

class _CollectionPickerBody extends StatefulWidget {
  const _CollectionPickerBody({
    required this.title,
    required this.collections,
    required this.onPick,
    required this.onCreateAndPick,
  });

  final String title;
  final List<SheetCollection> collections;
  final ValueChanged<String> onPick;
  final ValueChanged<String> onCreateAndPick;

  @override
  State<_CollectionPickerBody> createState() => _CollectionPickerBodyState();
}

class _CollectionPickerBodyState extends State<_CollectionPickerBody> {
  bool _creating = false;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSheetTitle(widget.title, bottomGap: 4),
        Text(
          'Pilih koleksi tujuan untuk komik ini.',
          style: AppTypography.jakarta(
            size: 12.5,
            weight: FontWeight.w400,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 14),
        for (final col in widget.collections)
          _CollectionRow(
            collection: col,
            trailing: col.selected
                ? const Icon(AppIcons.downloaded,
                    size: 19, color: AppColors.accent)
                : null,
            onTap: () {
              Navigator.pop(context);
              widget.onPick(col.name);
            },
          ),
        const SizedBox(height: 10),
        if (_creating)
          Row(
            children: [
              Expanded(
                child: _NewCollectionField(
                  controller: _controller,
                  height: 46,
                  borderColor: AppColors.accentBorderFaint,
                ),
              ),
              const SizedBox(width: 8),
              _CreateButton(
                controller: _controller,
                height: 46,
                onCreate: (name) {
                  Navigator.pop(context);
                  widget.onCreateAndPick(name);
                },
              ),
            ],
          )
        else
          InkWell(
            onTap: () => setState(() => _creating = true),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.accentBgFaint,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accentBorderFaint),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(AppIcons.add,
                      size: 17, color: AppColors.accentText),
                  const SizedBox(width: 8),
                  Text(
                    'Buat koleksi baru',
                    style: AppTypography.jakarta(
                      size: 14,
                      weight: FontWeight.w700,
                      color: AppColors.accentText,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Manage collections — spek 15: daftar koleksi + tombol hapus per row,
/// input + "Buat" persisten di bawah. Hapus koleksi tidak menghapus komiknya.
Future<void> showManageCollectionsSheet(
  BuildContext context, {
  required List<SheetCollection> collections,
  required ValueChanged<String> onDelete,
  required ValueChanged<String> onCreate,
}) {
  return showAppSheet(
    context,
    builder: (sheetContext) => _ManageCollectionsBody(
      collections: collections,
      onDelete: onDelete,
      onCreate: onCreate,
    ),
  );
}

class _ManageCollectionsBody extends StatefulWidget {
  const _ManageCollectionsBody({
    required this.collections,
    required this.onDelete,
    required this.onCreate,
  });

  final List<SheetCollection> collections;
  final ValueChanged<String> onDelete;
  final ValueChanged<String> onCreate;

  @override
  State<_ManageCollectionsBody> createState() => _ManageCollectionsBodyState();
}

class _ManageCollectionsBodyState extends State<_ManageCollectionsBody> {
  late final List<SheetCollection> _items = [...widget.collections];
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSheetTitle('Kelola koleksi', bottomGap: 14),
        for (final col in _items)
          _CollectionRow(
            collection: col,
            verticalPadding: 12,
            trailing: InkWell(
              onTap: () {
                setState(() => _items.remove(col));
                widget.onDelete(col.name);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.dangerBorder),
                ),
                child: const Icon(AppIcons.delete,
                    size: 15, color: AppColors.danger),
              ),
            ),
          ),
        Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.only(top: 14),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _NewCollectionField(
                  controller: _controller,
                  height: 48,
                  borderColor: AppColors.borderStrong,
                ),
              ),
              const SizedBox(width: 8),
              _CreateButton(
                controller: _controller,
                height: 48,
                horizontalPadding: 18,
                onCreate: (name) {
                  setState(() {
                    _items.add(SheetCollection(name: name, count: 0));
                    _controller.clear();
                  });
                  widget.onCreate(name);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CollectionRow extends StatelessWidget {
  const _CollectionRow({
    required this.collection,
    this.trailing,
    this.onTap,
    this.verticalPadding = 14,
  });

  final SheetCollection collection;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      highlightColor: AppColors.rowHighlight,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: verticalPadding, horizontal: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceSunken,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(LucideIcons.folder,
                  size: 18, color: AppColors.accentText),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(collection.name, style: AppTypography.rowTitle),
                  Text(
                    '${collection.count} komik',
                    style: AppTypography.jakarta(
                      size: 11.5,
                      weight: FontWeight.w400,
                      color: AppColors.textFaintestAlt,
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _NewCollectionField extends StatelessWidget {
  const _NewCollectionField({
    required this.controller,
    required this.height,
    required this.borderColor,
  });

  final TextEditingController controller;
  final double height;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: TextField(
        controller: controller,
        style: AppTypography.jakarta(size: 14, weight: FontWeight.w400),
        cursorColor: AppColors.accent,
        decoration: InputDecoration(
          hintText: 'Nama koleksi baru',
          hintStyle: AppTypography.jakarta(
            size: 14,
            weight: FontWeight.w400,
            color: AppColors.textFaint,
          ),
          filled: true,
          fillColor: AppColors.bg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.accent),
          ),
        ),
      ),
    );
  }
}

/// Tombol "Buat" — disabled (bg #2a2a35) saat input kosong, accent saat terisi.
class _CreateButton extends StatelessWidget {
  const _CreateButton({
    required this.controller,
    required this.height,
    required this.onCreate,
    this.horizontalPadding = 16,
  });

  final TextEditingController controller;
  final double height;
  final ValueChanged<String> onCreate;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final name = value.text.trim();
        final enabled = name.isNotEmpty;
        return SizedBox(
          height: height,
          child: FilledButton(
            onPressed: enabled ? () => onCreate(name) : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              disabledBackgroundColor: AppColors.switchTrackOff,
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: AppTypography.buttonSmall,
            ),
            child: const Text('Buat'),
          ),
        );
      },
    );
  }
}
