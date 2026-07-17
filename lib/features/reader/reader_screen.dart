import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/bookmarks_state.dart';
import '../../data/history_state.dart';
import '../../data/library_state.dart';
import '../../data/models.dart';
import '../../data/reader_settings.dart';
import '../../data/source_resolver.dart';
import '../../data/sources_state.dart';
import '../../sources/manga_source.dart';
import '../detail/comic_detail_screen.dart';
import 'reader_settings_sheet.dart';

const _mockTotalPages = 8;

/// Reader — spek 13: mode webtoon (scroll vertikal) & manga (per halaman,
/// opsi R→L), chrome toggle, slider dua arah, navigasi chapter.
///
/// "Sumber asli" ditentukan dari `comic.sourceMangaUrl` (bukan dari
/// [sourceChapters] terisi/tidak) — kalau komiknya dari sumber asli tapi
/// [sourceChapters] belum di-fetch oleh pemanggil (mis. tombol "play" di
/// History, yang cuma tahu nomor chapter terakhir), Reader fetch sendiri
/// daftar chapternya (lihat `_loadChapterList`). Ini penting: pemanggil
/// yang lupa/tidak sempat fetch dulu tidak akan diam-diam jatuh ke mode
/// demo/placeholder — satu-satunya komik yang benar-benar pakai placeholder
/// gradient adalah yang `sourceMangaUrl`-nya null (demo/lokal).
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.comic,
    required this.chapter,
    this.fromDetail = false,
    this.sourceChapters,
    this.initialChapterUrl,
  });

  final Comic comic;
  final int chapter;

  /// true bila di-push dari Comic Detail — "Lihat detail komik" cukup pop.
  final bool fromDetail;

  /// Daftar chapter asli kalau pemanggil sudah pernah fetch (mis. Comic
  /// Detail) — opsional murni buat optimisasi (hindari fetch dua kali);
  /// kalau null tapi komiknya dari sumber asli, Reader fetch sendiri.
  final List<SourceChapter>? sourceChapters;

  /// Chapter yang dibuka pertama kali (harus ada di [sourceChapters] kalau
  /// itu disediakan — kalau null, [chapter] dipetakan balik ke index
  /// setelah Reader selesai fetch sendiri).
  final String? initialChapterUrl;

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

  /// Key viewport `ListView` webtoon + key tiap halaman yang sedang
  /// ter-render — dipakai [_onScroll] buat baca posisi NYATA (bukan
  /// estimasi), lihat catatan di sana.
  final GlobalKey _viewportKey = GlobalKey();
  final Map<int, GlobalKey> _pageKeys = {};
  bool _scrollComputeScheduled = false;

  int? _sourceChapterIndex;
  List<SourcePage>? _realPages;
  bool _pagesLoading = false;
  String? _pagesError;
  int _pagesRequestId = 0;

  /// Daftar chapter asli — dari [widget.sourceChapters] kalau pemanggil
  /// sudah pernah fetch (mis. Comic Detail), atau di-fetch sendiri di sini
  /// kalau belum (mis. tombol "play" di History yang cuma tahu nomor
  /// chapter terakhir, bukan daftar lengkapnya) — lihat [_loadChapterList].
  /// Tanpa ini, Reader diam-diam jatuh ke mode demo/placeholder walau
  /// komiknya sungguhan dari sumber asli.
  List<SourceChapter>? _chapters;
  bool _chaptersLoading = false;
  String? _chaptersError;

  /// Diambil sekali di [initState] dan dipakai lagi lewat referensi ini —
  /// BUKAN `ref.read(...)` fresh tiap kali — karena [_saveProgress] juga
  /// dipanggil dari [dispose] (lewat [_flushPendingSave], nyimpen progres
  /// terakhir pas Reader ditutup). Riverpod nolak `ref.read`/`ref.watch`
  /// begitu widget "about to or has been unmounted" (`Bad state: Using
  /// "ref" when a widget is about to or has been unmounted is unsafe`,
  /// ke-reproduksi lewat smoke-test) — itu salah satu penyebab konkret
  /// laporan "progres kadang gak kesimpan": justru pas KELUAR dari
  /// chapter itulah kesempatan terakhir buat nyimpen, dan itu juga momen
  /// paling rawan exception ini. Notifier-nya sendiri aman disimpan &
  /// dipanggil kapan saja (provider-nya bukan `.autoDispose`, hidup
  /// sepanjang sesi app) — cuma `ref.read(...)`-nya yang harus dihindari
  /// begitu widget mulai di-unmount.
  late final HistoryNotifier _historyNotifier;
  late final LibraryNotifier _libraryNotifier;

  bool get _isRealSource => widget.comic.sourceMangaUrl != null;
  int get _totalPages => _realPages?.length ?? _mockTotalPages;

  /// false selama halaman chapter asli masih dimuat/loading — sebelum ini,
  /// [_totalPages] jatuh ke nilai mock (8) padahal jumlah halaman
  /// sebenarnya belum diketahui, jadi counter/slider bawah sempat
  /// menampilkan angka yang salah tiap ganti chapter.
  bool get _pageCountKnown => !_isRealSource || _realPages != null;

  MangaSource? get _matchedSource =>
      resolveMangaSource(widget.comic.src, ref.read(sourcesProvider));

  @override
  void initState() {
    super.initState();
    _historyNotifier = ref.read(historyProvider.notifier);
    _libraryNotifier = ref.read(libraryProvider.notifier);
    _scrollController.addListener(_onScroll);
    _applyWakelock();
    if (_isRealSource) {
      final chapters = widget.sourceChapters;
      if (chapters != null) {
        _chapters = chapters;
        final idx = chapters.indexWhere(
          (c) => c.url == widget.initialChapterUrl,
        );
        _sourceChapterIndex = idx == -1 ? 0 : idx;
        _loadRealPages();
      } else {
        _loadChapterList();
      }
    }
    // Jadwalkan simpan progres begitu chapter dibuka — sebelumnya cuma
    // ke-trigger kalau scroll melewati batas halaman, jadi kalau baca
    // cepat/pendek tanpa scroll jauh, progres nggak pernah kesimpan.
    _scheduleProgressSave();
  }

  @override
  void dispose() {
    _flushPendingSave();
    _scrollController.dispose();
    WakelockPlus.disable().catchError(
      (Object e) => debugPrint('Wakelock gagal: $e'),
    );
    super.dispose();
  }

  /// Simpan SEKARANG kalau ada progres yang masih nunggu di debounce,
  /// alih-alih dibiarkan kena `cancel()` begitu `_scheduleProgressSave()`
  /// dipanggil lagi (lihat [_leavingChapter]). Aman dipanggil dari
  /// `dispose()` — tidak ada `setState`.
  void _flushPendingSave() {
    final pending = _progressDebounce?.isActive ?? false;
    _progressDebounce?.cancel();
    if (pending) _saveProgress();
  }

  /// Dipanggil SEBELUM state chapter/halaman berpindah (ganti chapter,
  /// lompat ke bookmark) — dua bug yang ini benerin:
  ///
  /// 1. **Progres ketiban chapter baru**: `_progressDebounce` cuma SATU
  ///    Timer buat seluruh sesi baca. Kalau user pindah chapter SEBELUM
  ///    debounce 2 detik chapter LAMA sempat jalan,
  ///    `_scheduleProgressSave()` yang dipanggil abis pindah nge-`cancel()`
  ///    timer lama itu tanpa pernah nyimpennya — progres chapter lama
  ///    ("2/24" dst) HILANG, ketiban timer baru yang bakal nyimpen data
  ///    chapter BARU begitu jalan. Flush dulu progres yang lagi ditunggu
  ///    SEBELUM ganti apa pun.
  /// 2. **"Sudah habis" gak kedetek**: tanda chapter selesai
  ///    (`markChapterRead`) cuma jalan kalau `_page` sempat kebaca sebagai
  ///    halaman terakhir lewat scroll listener (`_computeCurrentPage`,
  ///    lihat catatan di sana). Kalau user langsung tap tombol
  ///    Next/footer "Akhir chapter" pas SUDAH sebenarnya sampai bawah tapi
  ///    listener scroll-nya belum sempat kepanggil, chapter itu ketinggal
  ///    tidak ketandain selesai. Cek posisi sekali lagi di sini,
  ///    SEBELUM pindah, biar kesempatan terakhir ini kepakai.
  void _leavingChapter() {
    _computeCurrentPage();
    _flushPendingSave();
  }

  /// Fetch daftar chapter sendiri kalau pemanggil (mis. tombol "play" di
  /// History) cuma tahu nomor chapter terakhir, bukan daftar lengkapnya —
  /// tanpa ini, Reader diam-diam jatuh ke mode demo/placeholder walau
  /// komiknya sungguhan dari sumber asli.
  ///
  /// Cari chapter targetnya via [widget.initialChapterUrl] DULU kalau ada
  /// — itu identifier stabil. [widget.chapter] (nomor chapter) cuma
  /// posisi relatif ke total chapter SAAT nomor itu di-assign; kalau
  /// daftar chapter situsnya sudah berubah panjang sejak itu (chapter
  /// baru terbit), memetakan `chapters.length - widget.chapter` di fetch
  /// yang BEDA dari fetch aslinya bisa nunjuk ke chapter yang salah —
  /// itu sebabnya "Lanjut Baca" kadang lompat ke nomor yang meleset.
  /// Fallback ke posisi cuma untuk data lama yang belum punya URL
  /// tersimpan (dari sebelum fix ini).
  Future<void> _loadChapterList() async {
    final source = _matchedSource;
    final mangaUrl = widget.comic.sourceMangaUrl;
    if (source == null || mangaUrl == null) return;
    setState(() {
      _chaptersLoading = true;
      _chaptersError = null;
    });
    try {
      final chapters = await source.fetchChapterList(mangaUrl);
      if (!mounted) return;
      final byUrl = widget.initialChapterUrl == null
          ? -1
          : chapters.indexWhere((c) => c.url == widget.initialChapterUrl);
      final index = byUrl != -1 ? byUrl : chapters.length - widget.chapter;
      setState(() {
        _chapters = chapters;
        _sourceChapterIndex = (index >= 0 && index < chapters.length)
            ? index
            : 0;
        _chaptersLoading = false;
      });
      _loadRealPages();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chaptersError = '$e';
        _chaptersLoading = false;
      });
    }
  }

  /// [_pagesRequestId] menjaga dari race condition: kalau pindah chapter
  /// lagi sebelum fetch chapter sebelumnya selesai, dan fetch yang lama
  /// itu (karena jaringan lambat) baru resolve BELAKANGAN, hasilnya tidak
  /// boleh menimpa `_realPages` chapter yang sedang dibuka sekarang —
  /// itu sebabnya counter/slider halaman kadang kelihatan salah/tidak
  /// sesuai chapter yang aktif.
  Future<void> _loadRealPages() async {
    final source = _matchedSource;
    final index = _sourceChapterIndex;
    final chapters = _chapters;
    if (source == null || index == null || chapters == null) return;
    final requestId = ++_pagesRequestId;
    setState(() {
      _pagesLoading = true;
      _pagesError = null;
      _realPages = null;
    });
    try {
      final pages = await source.fetchPageList(chapters[index].url);
      if (!mounted || requestId != _pagesRequestId) return;
      setState(() {
        _realPages = pages;
        _pagesLoading = false;
      });
    } catch (e) {
      if (!mounted || requestId != _pagesRequestId) return;
      setState(() {
        _pagesError = '$e';
        _pagesLoading = false;
      });
    }
  }

  /// Progres (chapter/halaman) disimpan ke history + library dengan jeda
  /// ~2 detik biar tidak nulis tiap scroll — lihat docs/DATABASE.md.
  void _scheduleProgressSave() {
    _progressDebounce?.cancel();
    _progressDebounce = Timer(const Duration(seconds: 2), _saveProgress);
  }

  /// URL chapter yang lagi dibuka sekarang — identifier stabil dipakai
  /// buat simpan history/bookmark, lihat catatan di
  /// `HistoryEntry.chapterUrl`/`_loadChapterList`.
  String? get _currentChapterUrl {
    final chapters = _chapters;
    final index = _sourceChapterIndex;
    if (!_isRealSource || chapters == null || index == null) return null;
    return chapters[index].url;
  }

  void _saveProgress() {
    if (mounted &&
        _isRealSource &&
        !_pageCountKnown &&
        _pagesError == null &&
        _chaptersError == null) {
      // Total halaman ASLI belum diketahui (masih fetch daftar chapter
      // atau daftar halamannya, `_totalPages` jatuh ke nilai mock 8) —
      // kalau tetap disimpan sekarang, "pages" yang kesimpan ke
      // History/dipakai buat cek "sudah tamat" jadi SALAH (mock, bukan
      // angka asli mis. 24), dan begitu chapter lain dibuka nilainya
      // ketiban lagi lewat [_leavingChapter] — itu bug "progres kadang
      // gak kesimpan / kesimpan tapi kegantI ke angka salah" yang
      // dilaporkan. Coba lagi sebentar begitu halaman aslinya sudah
      // ketahuan (bukan drop begitu saja). Berhenti coba lagi kalau
      // fetch-nya sudah gagal permanen (`_pagesError`/`_chaptersError`),
      // atau widget-nya sudah/lagi di-unmount (`!mounted`, dipanggil dari
      // [dispose] lewat [_flushPendingSave]) — reschedule di situ percuma
      // (Timer barunya bakal manggil method ini lagi di State yang sudah
      // dibuang, cuma numpuk exception baru), lebih baik simpan seadanya
      // sekarang daripada progresnya ilang sama sekali.
      _scheduleProgressSave();
      return;
    }
    final comic = widget.comic;
    _historyNotifier
        .upsert(
          comicId: comic.id,
          title: comic.title,
          src: comic.src,
          hue: comic.hue,
          chNum: _chapter,
          page: _page + 1,
          pages: _totalPages,
          chapterUrl: _currentChapterUrl,
          chapterLabel: _chapterLabel,
        )
        .catchError((Object e) => _reportSaveError('history', e));
    _libraryNotifier
        .updateProgress(comic.id, read: _chapter)
        .catchError((Object e) => _reportSaveError('library', e));
    // Tandai chapter ini selesai kalau sudah di halaman terakhir — terpisah
    // dari updateProgress di atas (itu cuma "sedang buka chapter berapa",
    // bukan penanda per-chapter yang dipakai buat tampilan "Dibaca" di
    // Comic Detail).
    if (_pageCountKnown && _page + 1 >= _totalPages) {
      _libraryNotifier
          .markChapterRead(comic.id, _chapter)
          .catchError((Object e) => _reportSaveError('tandai selesai', e));
    }
  }

  /// Toast diagnostik sebelumnya (buat lacak bug "progres tidak ke-track")
  /// sudah dicabut — root cause-nya (orderBy + serverTimestamp di
  /// history_state.dart, lihat PROGRESS.md) sudah ketemu & dibenerin, dan
  /// beberapa fitur belakangan (bookmark, tanda "Dibaca", Updates) sudah
  /// terverifikasi jalan tanpa masalah simpan. Kembali silent-log saja —
  /// menampilkan pesan error Firestore mentah ke user bukan UX yang bagus.
  void _reportSaveError(String what, Object error) {
    debugPrint('Gagal menyimpan $what: $error');
  }

  void _applyWakelock() {
    final keepOn = ref.read(readerSettingsProvider).keepScreenOn;
    // `.catchError` — platform wake lock API bisa nolak (mis. web tanpa
    // izin/gesture pengguna, atau device tertentu) dan itu Future gagal
    // yang dibiarkan begitu saja (tidak di-await/ditangkap) jadi unhandled
    // exception yang nyembul belakangan (ke-reproduksi lewat smoke-test:
    // muncul persis pas Reader dibuka/ditutup, dua titik ini dipanggil).
    // Fitur keep-screen-on gagal tidak boleh sampai ganggu baca/nyimpen
    // progres — cukup log, jangan biarkan nyembul jadi error tak tertangani.
    final future = keepOn ? WakelockPlus.enable() : WakelockPlus.disable();
    future.catchError((Object e) => debugPrint('Wakelock gagal: $e'));
  }

  /// Perkiraan tinggi satu blok halaman webtoon + gap — dipakai untuk
  /// estimasi posisi scroll→halaman (slider). Placeholder demo pakai
  /// rasio tetap 2:3; gambar asli tingginya sebenarnya bervariasi
  /// (menyesuaikan rasio aslinya masing-masing, lihat [_webtoonPage]),
  /// jadi ini cuma perkiraan rata-rata (rasio umum halaman webtoon),
  /// bukan tinggi pasti — slider bisa sedikit meleset untuk komik asli.
  double _pageExtent(BuildContext context, ReaderSettings settings) {
    final width = MediaQuery.sizeOf(context).width;
    final estimated = _isRealSource ? width / 0.7 : width * 1.5;
    return estimated + settings.gap;
  }

  /// Scroll → slider: halaman = blok terakhir yang offset-atasnya berada
  /// di atas garis ~40% viewport — dipakai posisi RENDER NYATA tiap
  /// halaman (via [_pageKeys]), bukan estimasi tinggi rata-rata seperti
  /// sebelumnya. Estimasi lama (rasio manga standar) jauh meleset untuk
  /// strip webtoon yang biasanya jauh lebih tinggi dari lebar layar,
  /// jadi slider "mentok" duluan padahal chapter belum tamat — akibatnya
  /// juga bikin progres per-chapter salah kebaca "sudah tamat".
  ///
  /// `ScrollController` bisa memicu listener ini lebih dari sekali per
  /// frame selagi fling — dikumpulkan dulu (`_scrollComputeScheduled`)
  /// jadi perhitungan geometrinya cuma jalan SEKALI per frame lewat
  /// `addPostFrameCallback`, bukan tiap notifikasi scroll mentah. Tanpa
  /// ini kerasa "kurang mulus"/patah-patah pas scroll cepat.
  void _onScroll() {
    if (_suppressScroll || !_scrollController.hasClients) return;
    if (_scrollComputeScheduled) return;
    _scrollComputeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollComputeScheduled = false;
      _computeCurrentPage();
    });
  }

  void _computeCurrentPage() {
    if (!mounted || !_scrollController.hasClients) return;
    final settings = ref.read(readerSettingsProvider);
    if (!settings.isWebtoon) return;
    final position = _scrollController.position;
    // Sudah discroll sampai (atau nyaris) paling bawah — termasuk mentok di
    // footer "Akhir chapter" — pasti sudah lewat halaman terakhir. Cek ini
    // duluan, JANGAN cuma andalkan geometri per-halaman: kalau user diam
    // cukup lama di footer, halaman terakhir bisa ter-unmount (di luar
    // cache extent) dan ke-prune dari `_pageKeys` di bawah, jadi `best`
    // salah jatuh ke halaman yang lebih kecil — akibatnya kadang chapter
    // yang udah kelar dibaca penuh tetap gak ketandain "Dibaca" (tergantung
    // pas tidaknya timing debounce vs widget yang di-dispose).
    if (position.hasContentDimensions &&
        position.pixels >= position.maxScrollExtent - 4) {
      final last = _totalPages - 1;
      if (last != _page) {
        setState(() => _page = last);
        _scheduleProgressSave();
      }
      return;
    }
    final viewportBox =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null || !viewportBox.attached) return;
    final targetY =
        viewportBox.localToGlobal(Offset.zero).dy +
        viewportBox.size.height * 0.4;
    // Buang key halaman yang sudah tidak ter-mount (di luar cache
    // extent) — biar peta tidak terus membesar sepanjang chapter panjang.
    _pageKeys.removeWhere((_, key) => key.currentContext == null);
    int? best;
    for (final entry in _pageKeys.entries) {
      final box = entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (top <= targetY && (best == null || entry.key > best)) {
        best = entry.key;
      }
    }
    if (best != null && best != _page) {
      setState(() => _page = best!);
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
    if (_isRealSource) {
      _changeSourceChapter(delta);
      return;
    }
    final next = _chapter + delta;
    if (next < 1 || next > widget.comic.ch) {
      AppToast.show(
        context,
        delta > 0 ? 'Sudah chapter terakhir' : 'Sudah chapter pertama',
      );
      return;
    }
    _leavingChapter();
    setState(() {
      _chapter = next;
      _page = 0;
      _showChrome = true;
      _pageKeys.clear();
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    AppToast.show(context, 'Chapter $next');
    _scheduleProgressSave();
  }

  /// Daftar chapter urut terbaru→terlama — "Next" (delta +1, ch lebih
  /// baru) berarti maju ke index lebih kecil; "Prev" sebaliknya.
  void _changeSourceChapter(int delta) {
    final chapters = _chapters;
    if (chapters == null) return; // daftar chapter belum selesai di-fetch
    final current = _sourceChapterIndex ?? 0;
    final newIndex = current - delta;
    if (newIndex < 0 || newIndex >= chapters.length) {
      AppToast.show(
        context,
        delta > 0 ? 'Sudah chapter terakhir' : 'Sudah chapter pertama',
      );
      return;
    }
    _leavingChapter();
    setState(() {
      _sourceChapterIndex = newIndex;
      _chapter = chapters.length - newIndex;
      _page = 0;
      _showChrome = true;
      _pageKeys.clear();
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    AppToast.show(context, chapters[newIndex].name);
    _loadRealPages();
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

  /// Gradient halaman placeholder (formula prototipe) — dipakai saat
  /// komik demo, atau sebagai fallback loading/error gambar asli.
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

  String get _chapterLabel {
    final index = _sourceChapterIndex;
    final chapters = _chapters;
    if (_isRealSource && index != null && chapters != null) {
      return chapters[index].name;
    }
    return 'Chapter $_chapter';
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
            if (_isRealSource && _chaptersLoading)
              const Center(
                child: AppSpinner(
                  size: 30,
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            else if (_isRealSource && _chaptersError != null)
              _buildLoadError(
                'Gagal memuat daftar chapter.\n$_chaptersError',
                _loadChapterList,
              )
            else if (_isRealSource && _pagesLoading)
              const Center(
                child: AppSpinner(
                  size: 30,
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            else if (_isRealSource && _pagesError != null)
              _buildLoadError(
                'Gagal memuat halaman.\n$_pagesError',
                _loadRealPages,
              )
            else if (settings.isWebtoon)
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
            if (_showChrome) ...[_buildTopToolbar(), _buildBottomToolbar()],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadError(String message, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.jakarta(
                size: 13.5,
                weight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: onRetry,
              borderRadius: BorderRadius.circular(11),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  'Coba Lagi',
                  style: AppTypography.jakarta(
                    size: 13,
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

  /// Blok placeholder demo (gradient + "PAGE N") — dipakai komik lokal,
  /// dan sebagai fallback loading/error untuk gambar asli.
  Widget _mockPageBlock(int i, {bool large = false}) => DecoratedBox(
    decoration: BoxDecoration(gradient: _pageGradient(i)),
    child: _PageMock(number: i + 1, large: large),
  );

  /// Halaman webtoon: lebar penuh, tinggi menyesuaikan rasio ASLI gambar
  /// (bukan dipaksa 2:3+cover — itu yang bikin gambar kepotong).
  /// `cacheWidth` menyuruh Flutter decode gambar sesuai lebar layar saja
  /// (bukan resolusi asli yang bisa jauh lebih besar), jauh lebih ringan.
  Widget _webtoonPage(int i, double width, double dpr) {
    final pages = _realPages;
    if (pages == null || i >= pages.length) {
      return SizedBox(
        width: width,
        height: width * 1.5,
        child: _mockPageBlock(i),
      );
    }
    // RepaintBoundary + FilterQuality.low: raster tiap halaman diisolasi
    // (scroll tidak memicu repaint halaman lain) dan digambar lebih
    // ringan di GPU — penting untuk layar refresh rate tinggi (120Hz).
    return RepaintBoundary(
      child: Image.network(
        pages[i].imageUrl,
        width: width,
        fit: BoxFit.fitWidth,
        cacheWidth: (width * dpr).round(),
        filterQuality: FilterQuality.low,
        gaplessPlayback: true,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : AspectRatio(
                aspectRatio: 0.7,
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: _pageGradient(i)),
                  child: const Center(
                    child: AppSpinner(
                      size: 22,
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
        errorBuilder: (_, _, _) =>
            AspectRatio(aspectRatio: 0.7, child: _mockPageBlock(i)),
      ),
    );
  }

  Widget _buildWebtoon(ReaderSettings settings) {
    final width = MediaQuery.sizeOf(context).width;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // +2: spacer atas (index 0) & footer "Akhir chapter" (index terakhir).
    // cacheExtent lebih besar (2 layar) supaya halaman berikutnya mulai
    // di-load sebelum kelihatan, bukan pas mepet muncul di layar.
    return ListView.builder(
      key: _viewportKey,
      controller: _scrollController,
      padding: EdgeInsets.zero,
      scrollCacheExtent: const ScrollCacheExtent.viewport(2.0),
      itemCount: _totalPages + 2,
      itemBuilder: (context, index) {
        if (index == 0) return const SizedBox(height: 44);
        if (index == _totalPages + 1) {
          return GestureDetector(
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
          );
        }
        final i = index - 1;
        return Padding(
          key: _pageKeys.putIfAbsent(i, () => GlobalKey()),
          padding: EdgeInsets.only(bottom: settings.gap.toDouble()),
          child: _webtoonPage(i, width, dpr),
        );
      },
    );
  }

  Widget _buildManga(ReaderSettings settings) {
    final rtl = settings.direction == ReadingDirection.rtl;
    final pages = _realPages;
    final isReal = pages != null && _page < pages.length;
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: isReal
              ? RepaintBoundary(
                  child: Image.network(
                    pages[_page].imageUrl,
                    fit: BoxFit.contain,
                    cacheWidth:
                        (MediaQuery.sizeOf(context).width *
                                MediaQuery.devicePixelRatioOf(context))
                            .round(),
                    filterQuality: FilterQuality.low,
                    gaplessPlayback: true,
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                        ? child
                        : AspectRatio(
                            aspectRatio: AppDimens.coverAspectRatio,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: _pageGradient(_page),
                              ),
                              child: const Center(
                                child: AppSpinner(
                                  size: 26,
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                    errorBuilder: (_, _, _) => AspectRatio(
                      aspectRatio: AppDimens.coverAspectRatio,
                      child: _mockPageBlock(_page, large: true),
                    ),
                  ),
                )
              : AspectRatio(
                  aspectRatio: AppDimens.coverAspectRatio,
                  child: _mockPageBlock(_page, large: true),
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
            12,
            MediaQuery.paddingOf(context).top + 8,
            12,
            12,
          ),
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
                      _chapterLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                icon: _isCurrentPageBookmarked()
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                active: _isCurrentPageBookmarked(),
                onTap: _toggleBookmark,
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
                      _pageCountKnown ? '${_page + 1} / $_totalPages' : '–',
                      style:
                          AppTypography.jakarta(
                            size: 12,
                            weight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.7),
                          ).copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _pageCountKnown
                        ? _ReaderSlider(
                            value: _page.toDouble(),
                            max: (_totalPages - 1).toDouble(),
                            onChanged: (v) => _seekToPage(v.round()),
                          )
                        : const _ReaderSlider(
                            value: 0,
                            max: 1,
                            onChanged: null,
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
                        const Icon(
                          AppIcons.back,
                          size: 15,
                          color: Colors.white,
                        ),
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
                      child: const Icon(
                        LucideIcons.slidersVertical,
                        size: 19,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _chapterNavButton(
                      onTap: () => _changeChapter(1),
                      children: [
                        _navLabel('Next'),
                        const SizedBox(width: 6),
                        const Icon(
                          AppIcons.forward,
                          size: 15,
                          color: Colors.white,
                        ),
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
    bool active = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.28)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(
          icon,
          size: 19,
          color: active ? AppColors.accentText : Colors.white,
        ),
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
      onViewBookmarks: _openBookmarks,
    );
  }

  bool _isCurrentPageBookmarked() {
    final comic = widget.comic;
    final id = BookmarksNotifier.idFor(comic.id, _chapter, _page + 1);
    return ref.watch(bookmarksProvider).any((b) => b.id == id);
  }

  /// Tandai/lepas halaman yang lagi dibuka sebagai bookmark ("momen
  /// epic") — beda dari progres baca biasa, tidak ketimpa/hilang saat
  /// lanjut baca, dan bisa banyak per komik lewat [_openBookmarks].
  void _toggleBookmark() {
    final comic = widget.comic;
    final wasBookmarked = ref
        .read(bookmarksProvider)
        .any(
          (b) => b.id == BookmarksNotifier.idFor(comic.id, _chapter, _page + 1),
        );
    ref
        .read(bookmarksProvider.notifier)
        .toggle(
          comicId: comic.id,
          title: comic.title,
          src: comic.src,
          hue: comic.hue,
          chNum: _chapter,
          chapterLabel: _chapterLabel,
          page: _page + 1,
          pages: _totalPages,
          chapterUrl: _currentChapterUrl,
        )
        .catchError((Object e) => _reportSaveError('bookmark', e));
    AppToast.show(
      context,
      wasBookmarked ? 'Bookmark dihapus' : 'Bookmark disimpan',
    );
  }

  void _openBookmarks() {
    final comic = widget.comic;
    final items = ref
        .read(bookmarksProvider.notifier)
        .forComic(comic.id)
        .map(
          (b) => BookmarkListItem(
            id: b.id,
            chNum: b.chNum,
            chapterLabel: b.chapterLabel,
            page: b.page,
            pages: b.pages,
            chapterUrl: b.chapterUrl,
          ),
        )
        .toList();
    showBookmarkListSheet(
      context,
      items: items,
      onTapItem: _jumpToBookmark,
      onRemoveItem: (item) => ref
          .read(bookmarksProvider.notifier)
          .remove(item.id)
          .catchError((Object e) => _reportSaveError('hapus bookmark', e)),
    );
  }

  /// Lompat ke chapter+halaman tempat bookmark ditandai. Untuk sumber asli,
  /// dicari via [BookmarkListItem.chapterUrl] dulu (identifier stabil) —
  /// fallback ke posisi (`chapters.length - chNum`) cuma untuk bookmark
  /// lama yang belum punya URL tersimpan (lihat catatan di
  /// `_loadChapterList`, kenapa posisi doang bisa meleset). Posisi scroll
  /// hasil [_seekToPage] tetap perkiraan (baca catatan di sana) sampai
  /// halaman targetnya kelihatan dan koreksi otomatis lewat
  /// [_computeCurrentPage] jalan.
  void _jumpToBookmark(BookmarkListItem item) {
    _leavingChapter();
    if (_isRealSource) {
      final chapters = _chapters;
      if (chapters == null) return; // daftar chapter belum selesai di-fetch
      final byUrl = item.chapterUrl == null
          ? -1
          : chapters.indexWhere((c) => c.url == item.chapterUrl);
      final targetIndex = byUrl != -1 ? byUrl : chapters.length - item.chNum;
      if (targetIndex < 0 || targetIndex >= chapters.length) return;
      setState(() {
        _sourceChapterIndex = targetIndex;
        _chapter = item.chNum;
        _page = (item.page - 1).clamp(0, 999);
        _showChrome = true;
        _pageKeys.clear();
      });
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
      _loadRealPages().then((_) {
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) => _seekToPage(_page));
      });
    } else {
      setState(() {
        _chapter = item.chNum;
        _page = (item.page - 1).clamp(0, _totalPages - 1);
        _showChrome = true;
      });
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) => _seekToPage(_page));
    }
    _scheduleProgressSave();
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
  final ValueChanged<double>? onChanged;

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
/// Dipakai untuk komik demo, dan sebagai fallback error gambar asli.
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
