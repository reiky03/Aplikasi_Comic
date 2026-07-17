import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/bookmarks_state.dart';
import '../../data/downloads_state.dart';
import '../../data/history_state.dart';
import '../../data/library_state.dart';
import '../../data/models.dart';
import '../../data/source_resolver.dart';
import '../../data/sources_state.dart';
import '../../sources/manga_source.dart';
import '../reader/reader_screen.dart';

/// Comic Detail — spek 12. Bila [comic] berasal dari sumber asli (lihat
/// lib/sources/, ditandai `sourceMangaUrl` non-null), deskripsi/genre/
/// status/daftar chapter diambil sungguhan lewat `MangaSource`; kalau
/// bukan (komik demo/lokal), tampilan prototipe apa adanya.
class ComicDetailScreen extends ConsumerStatefulWidget {
  const ComicDetailScreen({
    super.key,
    required this.comic,
    this.initialChapter,
  });

  /// Komik yang dibuka (bisa dari library, updates, history, discover).
  final Comic comic;

  /// Chapter relevan saat dibuka dari History/Updates.
  final int? initialChapter;

  @override
  ConsumerState<ComicDetailScreen> createState() => _ComicDetailScreenState();
}

class _ComicDetailScreenState extends ConsumerState<ComicDetailScreen> {
  SourceMangaDetails? _realDetails;
  List<SourceChapter>? _realChapters;
  bool _loading = false;
  String? _error;

  /// true = chapter terbaru (nomor besar) di atas, seperti sebelumnya.
  bool _sortDescending = true;

  MangaSource? get _matchedSource =>
      resolveMangaSource(widget.comic.src, ref.read(sourcesProvider));

  @override
  void initState() {
    super.initState();
    if (widget.comic.sourceMangaUrl != null) _loadReal();
  }

  Future<void> _loadReal() async {
    final source = _matchedSource;
    final mangaUrl = widget.comic.sourceMangaUrl;
    if (source == null || mangaUrl == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        source.fetchMangaDetails(mangaUrl),
        source.fetchChapterList(mangaUrl),
      ]);
      if (!mounted) return;
      setState(() {
        _realDetails = results[0] as SourceMangaDetails;
        _realChapters = results[1] as List<SourceChapter>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  /// Versi terkini dari library bila ada (progress bisa berubah).
  Comic _current(WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    for (final c in library) {
      if (c.id == widget.comic.id) return c;
    }
    return widget.comic;
  }

  @override
  Widget build(BuildContext context) {
    final current = _current(ref);
    final library = ref.watch(libraryProvider);
    final inLibrary = library.any((c) => c.id == current.id);
    final chapters = _chaptersToShow(current);
    final readCount = chapters.where((c) => c.read).length;
    final totalChapters = _realChapters?.length ?? current.ch;
    final orderedChapters =
        _sortDescending ? chapters : chapters.reversed.toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _loading
          ? _buildLoading(context)
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeaderSection(
                    context,
                    ref,
                    current,
                    inLibrary,
                    chapters,
                    readCount,
                    totalChapters,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  sliver: SliverList(
                    // Lazy: cuma chapter dekat viewport yang di-build —
                    // penting untuk komik dengan ratusan chapter.
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _ChapterRow(
                        comic: current,
                        chapter: orderedChapters[i],
                        onTap: () => _openReader(
                            context, current, orderedChapters[i].num),
                      ),
                      childCount: orderedChapters.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            ),
    );
  }

  Widget _buildHeaderSection(
    BuildContext context,
    WidgetRef ref,
    Comic current,
    bool inLibrary,
    List<_Chapter> chapters,
    int readCount,
    int totalChapters,
  ) {
    return Column(
      children: [
        _buildHero(context, current),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Text(
            _realDetails?.description ??
                (widget.comic.sourceMangaUrl != null
                    ? (_error != null ? 'Gagal memuat deskripsi.' : '')
                    : 'Ketika langit di atas kota retak dan '
                          'menumpahkan cahaya asing, seorang kurir '
                          'muda menemukan bahwa ingatannya adalah '
                          'kunci untuk menutup celah antar-dunia. '
                          'Perjalanan melintasi reruntuhan yang indah '
                          'dan berbahaya pun dimulai.'),
            style: AppTypography.jakarta(
              size: 13.5,
              weight: FontWeight.w400,
              height: 1.6,
              color: const Color(0xFFB9B9C6),
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: InkWell(
              onTap: _loadReal,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderStrong),
                ),
                child: Text(
                  'Gagal memuat chapter — Coba Lagi',
                  style: AppTypography.jakarta(
                    size: 12.5,
                    weight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
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
                  onTap: chapters.isEmpty
                      ? null
                      : () => _openReader(
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
                        const Icon(
                          Icons.play_arrow_rounded,
                          size: 22,
                          color: Colors.white,
                        ),
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
                      size: 15,
                      weight: FontWeight.w800,
                    ),
                    children: [
                      TextSpan(
                        text: '($totalChapters)',
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
              const SizedBox(width: 10),
              InkWell(
                onTap: () =>
                    setState(() => _sortDescending = !_sortDescending),
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: AppColors.sheetTopBorder),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _sortDescending
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    size: 15,
                    color: AppColors.menuIcon,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Stack(
      children: [
        _buildHero(context, widget.comic),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 40,
          child: Center(child: AppSpinner(size: 26, strokeWidth: 2.5)),
        ),
      ],
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
                child: current.coverUrl == null
                    ? null
                    : Image.network(
                        current.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(),
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
                  16,
                  MediaQuery.paddingOf(context).top + 4,
                  16,
                  0,
                ),
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
                        child: const Icon(
                          AppIcons.back,
                          size: 20,
                          color: Colors.white,
                        ),
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
                      clipBehavior: Clip.antiAlias,
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
                      child: comicCoverContent(
                        coverUrl: current.coverUrl,
                        initial: current.initial,
                        fontSize: 46,
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
                              _subtitleLine(),
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
                                for (final genre in _genresToShow())
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
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

  List<String> _genresToShow() {
    final real = _realDetails;
    if (real != null) return real.genres.take(4).toList();
    if (widget.comic.sourceMangaUrl != null) return const [];
    return const ['Action', 'Fantasy', 'Drama'];
  }

  String _subtitleLine() {
    final real = _realDetails;
    if (real == null) {
      return widget.comic.sourceMangaUrl != null
          ? ''
          : 'Kaze Aoyama · Berlangsung';
    }
    final parts = [
      if (real.author != null && real.author!.isNotEmpty) real.author!,
      _statusLabel(real.status),
    ].where((s) => s.isNotEmpty);
    return parts.join(' · ');
  }

  String _statusLabel(SourceMangaStatus status) => switch (status) {
    SourceMangaStatus.ongoing => 'Berlangsung',
    SourceMangaStatus.completed => 'Tamat',
    SourceMangaStatus.hiatus => 'Hiatus',
    SourceMangaStatus.cancelled => 'Dihentikan',
    SourceMangaStatus.unknown => '',
  };

  /// Chapter list top-down dari total ke 1. Pakai data asli kalau ada
  /// (lihat [_realChapters]), kalau tidak pakai demo prototipe. Progres
  /// baca per-chapter (lihat [_Chapter.progressLabel]) diambil dari
  /// `history` (posisi baca terakhir) — bukan cuma tanda "Dibaca"/belum,
  /// tapi "baru sampai halaman berapa" untuk chapter yang sedang dibaca.
  List<_Chapter> _chaptersToShow(Comic comic) {
    final progress = _inProgressEntry(comic);
    final bookmarked = ref
        .watch(bookmarksProvider)
        .where((b) => b.comicId == comic.id)
        .map((b) => b.chNum)
        .toSet();
    final real = _realChapters;
    if (real == null) return _makeDemoChapters(comic, progress, bookmarked);
    final total = real.length;
    return [
      for (var i = 0; i < real.length; i++)
        _buildChapter(
          num: total - i,
          title: real[i].name,
          date: _relativeDate(real[i].dateUpload),
          comic: comic,
          progress: progress,
          bookmarked: bookmarked,
        ),
    ];
  }

  /// Entri history untuk komik ini (posisi baca terakhir), kalau ada.
  HistoryEntry? _inProgressEntry(Comic comic) {
    for (final h in ref.watch(historyProvider)) {
      if (h.comicId == comic.id) return h;
    }
    return null;
  }

  _Chapter _buildChapter({
    required int num,
    required String title,
    required String date,
    required Comic comic,
    required HistoryEntry? progress,
    required Set<int> bookmarked,
  }) {
    final isCurrent = progress != null && progress.chNum == num;
    // Bukan `num < comic.read` (chapter terjauh yang pernah dibuka) — itu
    // salah nandain chapter LAMA sebagai "sudah dibaca" kalau user baru
    // baca satu chapter TERBARU (nomor besar) duluan, padahal belum pernah
    // buka yang lama sama sekali. Pakai [Comic.readChapters] (per-chapter,
    // ditandai saat halaman terakhirnya benar-benar tercapai).
    final fullyRead = comic.readChapters.contains(num) ||
        (isCurrent && progress.page >= progress.pages);
    return _Chapter(
      num: num,
      title: title,
      date: date,
      read: fullyRead,
      progressLabel:
          (isCurrent && !fullyRead) ? 'Hal ${progress.page}/${progress.pages}' : null,
      hasBookmark: bookmarked.contains(num),
    );
  }

  String _relativeDate(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inHours < 24) return 'Hari ini';
    if (diff.inDays < 2) return 'Kemarin';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} minggu lalu';
    return '${(diff.inDays / 30).floor()} bulan lalu';
  }

  List<_Chapter> _makeDemoChapters(
    Comic comic,
    HistoryEntry? progress,
    Set<int> bookmarked,
  ) {
    final total = comic.ch;
    return [
      for (var i = total; i >= 1; i--)
        _buildChapter(
          num: i,
          title: 'Chapter $i',
          date: i > total - 4
              ? '2 hari lalu'
              : i > total - 8
              ? '1 minggu lalu'
              : '${total - i} minggu lalu',
          comic: comic,
          progress: progress,
          bookmarked: bookmarked,
        ),
    ];
  }

  /// URL chapter asli untuk nomor sintetis [num] (lihat [_chaptersToShow]).
  String? _urlForChapterNum(int num) {
    final chapters = _realChapters;
    if (chapters == null) return null;
    final index = chapters.length - num;
    if (index < 0 || index >= chapters.length) return null;
    return chapters[index].url;
  }

  void _openReader(BuildContext context, Comic comic, int chapter) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReaderScreen(
          comic: comic,
          chapter: chapter,
          fromDetail: true,
          sourceChapters: _realChapters,
          initialChapterUrl: _urlForChapterNum(chapter),
        ),
      ),
    );
  }

  void _openCollectionPicker(
    BuildContext context,
    WidgetRef ref,
    Comic current,
  ) {
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
        // Isi total chapter sungguhan (comic dari discover awalnya ch: 0
        // karena belum ada info sampai fetchChapterList selesai). Isi juga
        // lastChapterUrl (chapter terbaru saat ini, list newest-first) —
        // baseline buat UpdatesNotifier deteksi chapter baru nanti.
        final chapters = _realChapters;
        final toSave = chapters == null
            ? current
            : Comic(
                id: current.id,
                title: current.title,
                src: current.src,
                hue: current.hue,
                ch: chapters.length,
                unread: current.unread,
                read: current.read,
                coverUrl: current.coverUrl,
                sourceMangaUrl: current.sourceMangaUrl,
                lastChapterUrl:
                    chapters.isNotEmpty ? chapters.first.url : null,
              );
        ref
            .read(libraryProvider.notifier)
            .add(toSave, collectionId: collectionId);
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
      onCreateAndPick: (name) async {
        final id = await ref.read(collectionsProvider.notifier).create(name);
        assign(id, name);
      },
    );
  }
}

class _Chapter {
  const _Chapter({
    required this.num,
    required this.title,
    required this.date,
    required this.read,
    required this.hasBookmark,
    this.progressLabel,
  });

  final int num;
  final String title;
  final String date;
  final bool read;

  /// Progres baca yang belum tuntas, mis. "Hal 10/40" — null kalau sudah
  /// tuntas dibaca ([read] true) atau belum pernah disentuh.
  final String? progressLabel;

  /// true kalau ada bookmark ("momen epic") di chapter ini — lihat
  /// lib/data/bookmarks_state.dart.
  final bool hasBookmark;
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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          chapter.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.jakarta(
                            size: 14,
                            weight: FontWeight.w600,
                            color: chapter.read
                                ? AppColors.textFaint
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (chapter.hasBookmark) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.bookmark_rounded,
                            size: 13, color: AppColors.accentText),
                      ],
                    ],
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
            ] else if (chapter.progressLabel != null) ...[
              Text(
                chapter.progressLabel!,
                style: AppTypography.jakarta(
                  size: 10.5,
                  weight: FontWeight.w700,
                  color: AppColors.accentText,
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
                  color: downloaded ? AppColors.accent : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
