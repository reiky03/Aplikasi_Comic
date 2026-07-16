import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/downloads_state.dart';
import '../../data/library_state.dart';
import '../../data/models.dart';
import '../reader/reader_screen.dart';

/// Comic Detail — spek 12.
class ComicDetailScreen extends ConsumerWidget {
  const ComicDetailScreen({
    super.key,
    required this.comic,
    this.initialChapter,
  });

  /// Komik yang dibuka (bisa dari library, updates, history, discover).
  final Comic comic;

  /// Chapter relevan saat dibuka dari History/Updates.
  final int? initialChapter;

  /// Versi terkini dari library bila ada (progress bisa berubah).
  Comic _current(WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    for (final c in library) {
      if (c.id == comic.id) return c;
    }
    return comic;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = _current(ref);
    final library = ref.watch(libraryProvider);
    final inLibrary = library.any((c) => c.id == current.id);
    final chapters = _makeChapters(current);
    final readCount = chapters.where((c) => c.read).length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          _buildHero(context, current),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Text(
              'Ketika langit di atas kota retak dan menumpahkan cahaya asing, '
              'seorang kurir muda menemukan bahwa ingatannya adalah kunci '
              'untuk menutup celah antar-dunia. Perjalanan melintasi '
              'reruntuhan yang indah dan berbahaya pun dimulai.',
              style: AppTypography.jakarta(
                size: 13.5,
                weight: FontWeight.w400,
                height: 1.6,
                color: const Color(0xFFB9B9C6),
              ),
            ),
          ),
          // Action row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
            child: Row(
              children: [
                InkWell(
                  onTap: () => _openCollectionPicker(context, ref, current),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: inLibrary ? const Color(0x291E88C8) : null,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: inLibrary
                            ? const Color(0x801E88C8)
                            : AppColors.borderStrong,
                      ),
                    ),
                    child: Icon(
                      inLibrary ? Icons.bookmark : AppIcons.bookmark,
                      size: 22,
                      color: inLibrary
                          ? AppColors.accentText
                          : AppColors.menuIcon,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: InkWell(
                    onTap: () => _openReader(
                      context,
                      current,
                      current.read > 0 ? current.read + 1 : 1,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.play_arrow_rounded,
                              size: 22, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            current.read > 0 ? 'Lanjut Baca' : 'Mulai Baca',
                            style: AppTypography.jakarta(
                              size: 15,
                              weight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Chapter list header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: 'Chapter ',
                      style: AppTypography.jakarta(
                          size: 15, weight: FontWeight.w800),
                      children: [
                        TextSpan(
                          text: '(${current.ch})',
                          style: AppTypography.jakarta(
                            size: 15,
                            weight: FontWeight.w600,
                            color: AppColors.textFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  '$readCount dibaca',
                  style: AppTypography.jakarta(
                    size: 12,
                    weight: FontWeight.w400,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                for (final chapter in chapters)
                  _ChapterRow(
                    comic: current,
                    chapter: chapter,
                    onTap: () =>
                        _openReader(context, current, chapter.num),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, Comic current) {
    final cover = comicCover(current.hue);
    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            children: [
              Container(
                height: 230,
                decoration: BoxDecoration(gradient: cover),
                foregroundDecoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x590E0E13), AppColors.bg],
                  ),
                ),
              ),
              const Expanded(child: ColoredBox(color: AppColors.bg)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                    16, MediaQuery.paddingOf(context).top + 4, 16, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        color: Colors.black.withValues(alpha: 0.4),
                        child: const Icon(AppIcons.back,
                            size: 20, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 108,
                      height: 150,
                      decoration: BoxDecoration(
                        gradient: cover,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xCC000000),
                            offset: Offset(0, 14),
                            blurRadius: 30,
                            spreadRadius: -10,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        current.initial,
                        style: AppTypography.jakarta(
                          size: 46,
                          weight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              current.title,
                              style: AppTypography.jakarta(
                                size: 20,
                                weight: FontWeight.w800,
                                height: 1.2,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              current.src,
                              style: AppTypography.jakarta(
                                size: 13,
                                weight: FontWeight.w600,
                                color: AppColors.accentText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Kaze Aoyama · Berlangsung',
                              style: AppTypography.jakarta(
                                size: 12.5,
                                weight: FontWeight.w400,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final genre in const [
                                  'Action',
                                  'Fantasy',
                                  'Drama'
                                ])
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 9, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceSunken,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      genre,
                                      style: AppTypography.jakarta(
                                        size: 10.5,
                                        weight: FontWeight.w600,
                                        color: AppColors.menuIcon,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Chapter list top-down dari total ke 1 (logika prototipe).
  List<_Chapter> _makeChapters(Comic comic) {
    final total = comic.ch;
    final readUpTo = comic.read;
    return [
      for (var i = total; i >= 1; i--)
        _Chapter(
          num: i,
          date: i > total - 4
              ? '2 hari lalu'
              : i > total - 8
                  ? '1 minggu lalu'
                  : '${total - i} minggu lalu',
          read: i <= readUpTo,
        ),
    ];
  }

  void _openReader(BuildContext context, Comic comic, int chapter) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ReaderScreen(comic: comic, chapter: chapter, fromDetail: true),
      ),
    );
  }

  void _openCollectionPicker(
      BuildContext context, WidgetRef ref, Comic current) {
    final collections = ref.read(collectionsProvider);
    final library = ref.read(libraryProvider);
    final inLibrary = library.any((c) => c.id == current.id);

    void assign(String collectionId, String collectionName) {
      if (inLibrary) {
        ref
            .read(libraryProvider.notifier)
            .moveToCollection(current.id, collectionId);
        AppToast.show(context, 'Dipindahkan koleksi');
      } else {
        ref
            .read(libraryProvider.notifier)
            .add(current, collectionId: collectionId);
        AppToast.show(context, 'Ditambahkan ke $collectionName');
      }
    }

    showCollectionPickerSheet(
      context,
      title: inLibrary ? 'Pindahkan ke koleksi' : 'Simpan ke koleksi',
      collections: [
        for (final col in collections)
          SheetCollection(
            name: col.name,
            count: library.where((c) => c.col == col.id).length,
            selected: inLibrary && current.col == col.id,
          ),
      ],
      onPick: (name) {
        final col = collections.firstWhere((c) => c.name == name);
        assign(col.id, col.name);
      },
      onCreateAndPick: (name) {
        final id = ref.read(collectionsProvider.notifier).create(name);
        assign(id, name);
      },
    );
  }
}

class _Chapter {
  const _Chapter({required this.num, required this.date, required this.read});

  final int num;
  final String date;
  final bool read;
}

class _ChapterRow extends ConsumerWidget {
  const _ChapterRow({
    required this.comic,
    required this.chapter,
    required this.onTap,
  });

  final Comic comic;
  final _Chapter chapter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadsProvider);
    final downloaded = downloads.contains('${comic.id}-${chapter.num}');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      highlightColor: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chapter ${chapter.num}',
                    style: AppTypography.jakarta(
                      size: 14,
                      weight: FontWeight.w600,
                      color: chapter.read
                          ? AppColors.textFaint
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    chapter.date,
                    style: AppTypography.jakarta(
                      size: 11.5,
                      weight: FontWeight.w400,
                      color: AppColors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
            if (chapter.read) ...[
              Text(
                'Dibaca',
                style: AppTypography.jakarta(
                  size: 10.5,
                  weight: FontWeight.w600,
                  color: const Color(0xFF5A5A6A),
                ),
              ),
              const SizedBox(width: 12),
            ],
            InkWell(
              onTap: () {
                final nowDownloaded = ref
                    .read(downloadsProvider.notifier)
                    .toggle(comic.id, chapter.num);
                AppToast.show(
                  context,
                  nowDownloaded ? 'Chapter diunduh' : 'Unduhan dihapus',
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: downloaded
                        ? const Color(0x801E88C8)
                        : AppColors.borderStrong,
                  ),
                ),
                child: Icon(
                  downloaded ? AppIcons.downloaded : AppIcons.download,
                  size: 15,
                  color:
                      downloaded ? AppColors.accent : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
