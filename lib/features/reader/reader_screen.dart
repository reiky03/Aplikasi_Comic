import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/history_state.dart';
import '../../data/library_state.dart';
import '../../data/models.dart';
import '../../data/reader_settings.dart';
import '../detail/comic_detail_screen.dart';
import 'reader_settings_sheet.dart';

const _totalPages = 8;

/// Reader — spek 13: mode webtoon (scroll vertikal) & manga (per halaman,
/// opsi R→L), chrome toggle, slider dua arah, navigasi chapter.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.comic,
    required this.chapter,
    this.fromDetail = false,
  });

  final Comic comic;
  final int chapter;

  /// true bila di-push dari Comic Detail — "Lihat detail komik" cukup pop.
  final bool fromDetail;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late int _chapter = widget.chapter;
  int _page = 0;
  bool _showChrome = true;
  bool _suppressScroll = false;
  final _scrollController = ScrollController();
  Timer? _progressDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _applyWakelock();
  }

  @override
  void dispose() {
    final pendingSave = _progressDebounce?.isActive ?? false;
    _progressDebounce?.cancel();
    if (pendingSave) _saveProgress();
    _scrollController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  /// Progres (chapter/halaman) disimpan ke history + library dengan jeda
  /// ~2 detik biar tidak nulis tiap scroll — lihat docs/DATABASE.md.
  void _scheduleProgressSave() {
    _progressDebounce?.cancel();
    _progressDebounce = Timer(const Duration(seconds: 2), _saveProgress);
  }

  void _saveProgress() {
    final comic = widget.comic;
    ref.read(historyProvider.notifier).upsert(
          comicId: comic.id,
          title: comic.title,
          src: comic.src,
          hue: comic.hue,
          chNum: _chapter,
          page: _page + 1,
          pages: _totalPages,
        );
    ref.read(libraryProvider.notifier).updateProgress(comic.id, read: _chapter);
  }

  void _applyWakelock() {
    final keepOn = ref.read(readerSettingsProvider).keepScreenOn;
    if (keepOn) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  // Tinggi satu blok halaman webtoon (2:3 dari lebar penuh) + gap.
  double _pageExtent(BuildContext context, ReaderSettings settings) =>
      MediaQuery.sizeOf(context).width * 1.5 + settings.gap;

  /// Scroll → slider: halaman = blok terakhir yang offset-atasnya berada
  /// di atas garis ~40% viewport (logika prototipe, dua arah wajib jalan).
  void _onScroll() {
    if (_suppressScroll || !_scrollController.hasClients) return;
    final settings = ref.read(readerSettingsProvider);
    if (!settings.isWebtoon) return;
    final mid = _scrollController.offset +
        _scrollController.position.viewportDimension * 0.4;
    final extent = _pageExtent(context, settings);
    var idx = ((mid - 44) / extent).floor();
    idx = idx.clamp(0, _totalPages - 1);
    if (idx != _page) {
      setState(() => _page = idx);
      _scheduleProgressSave();
    }
  }

  /// Slider → scroll.
  void _seekToPage(int idx) {
    final settings = ref.read(readerSettingsProvider);
    setState(() => _page = idx);
    _scheduleProgressSave();
    if (settings.isWebtoon && _scrollController.hasClients) {
      _suppressScroll = true;
      _scrollController.jumpTo(44 + idx * _pageExtent(context, settings));
      Future<void>.delayed(const Duration(milliseconds: 60), () {
        _suppressScroll = false;
      });
    }
  }

  void _changeChapter(int delta) {
    final next = _chapter + delta;
    if (next < 1 || next > widget.comic.ch) {
      AppToast.show(
        context,
        delta > 0 ? 'Sudah chapter terakhir' : 'Sudah chapter pertama',
      );
      return;
    }
    setState(() {
      _chapter = next;
      _page = 0;
      _showChrome = true;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    AppToast.show(context, 'Chapter $next');
    _scheduleProgressSave();
  }

  void _nextPage() {
    setState(() => _page = (_page + 1).clamp(0, _totalPages - 1));
    _scheduleProgressSave();
  }

  void _prevPage() {
    setState(() => _page = (_page - 1).clamp(0, _totalPages - 1));
    _scheduleProgressSave();
  }

  /// Gradient halaman placeholder (formula prototipe).
  Gradient _pageGradient(int i) {
    final hue = (widget.comic.hue + i * 10) % 360;
    final angle = (160 + i * 8) * 3.1415926535 / 180;
    return LinearGradient(
      transform: GradientRotation(angle - 3.1415926535 / 2),
      colors: [
        HSLColor.fromAHSL(1, hue.toDouble(), 0.30, 0.20).toColor(),
        HSLColor.fromAHSL(1, hue.toDouble(), 0.40, 0.09).toColor(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);
    final dimOpacity = (100 - settings.brightness) / 100 * 0.7;

    return Scaffold(
      backgroundColor: settings.bg,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _showChrome = !_showChrome),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (settings.isWebtoon)
              _buildWebtoon(settings)
            else
              _buildManga(settings),
            // Overlay kecerahan baca (independen dari brightness sistem).
            if (dimOpacity > 0)
              IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: dimOpacity),
                ),
              ),
            if (_showChrome) ...[
              _buildTopToolbar(),
              _buildBottomToolbar(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWebtoon(ReaderSettings settings) {
    final width = MediaQuery.sizeOf(context).width;
    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 44),
        for (var i = 0; i < _totalPages; i++)
          Container(
            width: width,
            height: width * 1.5,
            margin: EdgeInsets.only(bottom: settings.gap.toDouble()),
            decoration: BoxDecoration(gradient: _pageGradient(i)),
            child: _PageMock(number: i + 1),
          ),
        GestureDetector(
          onTap: () => _changeChapter(1),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 60),
            child: Text.rich(
              TextSpan(
                text: 'Akhir chapter · ',
                style: AppTypography.jakarta(
                  size: 13,
                  weight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                children: [
                  TextSpan(
                    text: 'Chapter berikutnya →',
                    style: AppTypography.jakarta(
                      size: 13,
                      weight: FontWeight.w700,
                      color: AppColors.accentText,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManga(ReaderSettings settings) {
    final rtl = settings.direction == ReadingDirection.rtl;
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: AppDimens.coverAspectRatio,
            child: Container(
              decoration: BoxDecoration(gradient: _pageGradient(_page)),
              child: _PageMock(number: _page + 1, large: true),
            ),
          ),
        ),
        // Tap zone kiri/kanan 32% — prev/next halaman (terbalik saat RTL).
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: MediaQuery.sizeOf(context).width * 0.32,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: rtl ? _nextPage : _prevPage,
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: MediaQuery.sizeOf(context).width * 0.32,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: rtl ? _prevPage : _nextPage,
          ),
        ),
      ],
    );
  }

  Widget _buildTopToolbar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onTap: () {}, // jangan toggle chrome saat tap toolbar
        child: Container(
          padding: EdgeInsets.fromLTRB(
              12, MediaQuery.paddingOf(context).top + 8, 12, 12),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xD1000000), Colors.transparent],
            ),
          ),
          child: Row(
            children: [
              _chromeButton(
                size: 38,
                icon: AppIcons.back,
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.comic.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.jakarta(
                        size: 14,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Chapter $_chapter',
                      style: AppTypography.jakarta(
                        size: 11.5,
                        weight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _chromeButton(
                size: 38,
                icon: AppIcons.more,
                onTap: _openMoreMenu,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0xE0000000), Colors.transparent],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${_page + 1} / $_totalPages',
                      style: AppTypography.jakarta(
                        size: 12,
                        weight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.7),
                      ).copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ReaderSlider(
                      value: _page.toDouble(),
                      max: (_totalPages - 1).toDouble(),
                      onChanged: (v) => _seekToPage(v.round()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _chapterNavButton(
                      onTap: () => _changeChapter(-1),
                      children: [
                        const Icon(AppIcons.back,
                            size: 15, color: Colors.white),
                        const SizedBox(width: 6),
                        _navLabel('Prev'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _openSettings,
                    borderRadius: BorderRadius.circular(11),
                    child: Container(
                      width: 46,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(LucideIcons.slidersVertical,
                          size: 19, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _chapterNavButton(
                      onTap: () => _changeChapter(1),
                      children: [
                        _navLabel('Next'),
                        const SizedBox(width: 6),
                        const Icon(AppIcons.forward,
                            size: 15, color: Colors.white),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Text _navLabel(String text) => Text(
        text,
        style: AppTypography.jakarta(
          size: 12.5,
          weight: FontWeight.w600,
          color: Colors.white,
        ),
      );

  Widget _chapterNavButton({
    required VoidCallback onTap,
    required List<Widget> children,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: children,
        ),
      ),
    );
  }

  Widget _chromeButton({
    required double size,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 19, color: Colors.white),
      ),
    );
  }

  void _openMoreMenu() {
    showReaderMoreMenu(
      context,
      onOpenComicDetail: () {
        if (widget.fromDetail) {
          Navigator.of(context).pop();
        } else {
          // Masuk dari History (play) — detail belum ada di stack.
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => ComicDetailScreen(comic: widget.comic),
            ),
          );
        }
      },
      onMarkUnread: () => AppToast.show(context, 'Ditandai belum dibaca'),
      onShareChapter: () => AppToast.show(context, 'Bagikan chapter'),
    );
  }

  void _openSettings() {
    showReaderSettingsSheet(context, onChanged: _applyWakelock);
  }
}

/// Slider tipis 4px accent (meniru input range prototipe).
class _ReaderSlider extends StatelessWidget {
  const _ReaderSlider({
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
        thumbColor: Colors.white,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        padding: EdgeInsets.zero,
      ),
      child: Slider(value: value, max: max, onChanged: onChanged),
    );
  }
}

/// Placeholder isi halaman (blok panel + label PAGE N) — persis prototipe.
class _PageMock extends StatelessWidget {
  const _PageMock({required this.number, this.large = false});

  final int number;
  final bool large;

  @override
  Widget build(BuildContext context) {
    Widget panel() => Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.sheetTopBorder),
          ),
        );
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          children: [
            Positioned(
              top: large ? 18 : 14,
              left: large ? 18 : 14,
              width: w * (large ? 0.55 : 0.6),
              height: h * (large ? 0.24 : 0.22),
              child: panel(),
            ),
            Positioned(
              bottom: h * (large ? 0.20 : 0.16),
              right: large ? 18 : 14,
              width: w * (large ? 0.48 : 0.45),
              height: h * (large ? 0.32 : 0.30),
              child: panel(),
            ),
            Center(
              child: Text(
                'PAGE $number',
                style: AppTypography.mono(
                  size: large ? 15 : 13,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
