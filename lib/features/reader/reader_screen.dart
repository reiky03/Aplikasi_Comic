import 'dart:async';
import 'dart:math' as math;

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
import '../../data/repository_state.dart';
import '../../data/source_resolver.dart';
import '../../data/source_url.dart';
import '../../data/sources_state.dart';
import '../../data/vpn_state.dart';
import '../../sources/manga_source.dart';
import '../detail/comic_detail_screen.dart';
import '../browse/web_view_screen.dart';
import 'reader_session_image_cache.dart';
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

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late int _chapter = widget.chapter;
  int _page = 0;
  bool _showChrome = true;
  bool _suppressScroll = false;
  final _scrollController = ScrollController();
  final _mangaZoomController = TransformationController();
  final _webtoonTransform = ValueNotifier<Matrix4>(Matrix4.identity());
  final _zoomRailScale = ValueNotifier<double>(1);
  final _readerImageCache = ReaderSessionImageCache();
  late final AnimationController _zoomAnimationController;
  Future<void>? _readerImageCacheReady;
  bool _readerImageCacheReleased = false;
  bool _mangaZoomed = false;
  double _webtoonZoomScale = 1;
  double _webtoonDecodeScale = 1;
  double _webtoonEdgeInset = 0;
  Offset _webtoonTranslation = Offset.zero;
  Size _webtoonViewportSize = Size.zero;
  double _zoomRailStartScale = 1;
  Offset _zoomRailFocalPoint = Offset.zero;
  Offset? _zoomRailWebtoonSceneAnchor;
  Offset? _zoomRailMangaSceneAnchor;
  bool _zoomRailPreviewing = false;
  bool _zoomAnimationWebtoon = false;
  double _zoomAnimationStartScale = 1;
  double _zoomAnimationTargetScale = 1;
  Offset _zoomAnimationFocalPoint = Offset.zero;
  Offset _zoomAnimationSceneAnchor = Offset.zero;
  int _webtoonZoomRequestId = 0;
  Timer? _webtoonDecodeTimer;
  Timer? _progressDebounce;

  /// Key viewport `ListView` webtoon + key tiap halaman yang sedang
  /// ter-render — dipakai [_onScroll] buat baca posisi NYATA (bukan
  /// estimasi), lihat catatan di sana.
  final GlobalKey _viewportKey = GlobalKey();
  final Map<int, GlobalKey> _pageKeys = {};
  bool _scrollComputeScheduled = false;
  final Set<String> _precachedPageKeys = {};
  final Map<String, double> _measuredPageAspectRatios = {};
  final Map<String, _PageGeometryLoad> _pageGeometryLoads = {};

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
  String? _chaptersWebViewUrl;
  String? _pagesWebViewUrl;

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

  MangaSource? get _matchedSource => resolveMangaSource(
    widget.comic.src,
    ref.read(sourcesProvider),
    ref.read(repositoriesProvider),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _zoomAnimationController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 200),
          )
          ..addListener(_onZoomAnimationTick)
          ..addStatusListener(_onZoomAnimationStatus);
    _historyNotifier = ref.read(historyProvider.notifier);
    _libraryNotifier = ref.read(libraryProvider.notifier);
    _scrollController.addListener(_onScroll);
    _mangaZoomController.addListener(_onMangaZoomChanged);
    _applyWakelock();
    if (_isRealSource) {
      // Clear cache sesi lama berjalan paralel dengan fetch chapter/page supaya
      // tidak menambah waktu tunggu yang terasa saat Reader pertama dibuka.
      _readerImageCacheReady = _readerImageCache.open();
      final chapters = widget.sourceChapters;
      if (chapters != null) {
        _chapters = chapters;
        final byUrl = widget.initialChapterUrl == null
            ? -1
            : chapters.indexWhere(
                (chapter) =>
                    sameChapterIdentity(chapter.url, widget.initialChapterUrl),
              );
        final fallback = chapters.length - widget.chapter;
        final target = byUrl != -1
            ? byUrl
            : (fallback >= 0 && fallback < chapters.length ? fallback : 0);
        _sourceChapterIndex = target;
        _chapter = chapters.length - target;
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
    WidgetsBinding.instance.removeObserver(this);
    _releaseReaderImageCache();
    _flushPendingSave();
    for (final load in _pageGeometryLoads.values) {
      load.dispose();
    }
    _pageGeometryLoads.clear();
    _scrollController.dispose();
    _webtoonTransform.dispose();
    _zoomRailScale.dispose();
    _webtoonDecodeTimer?.cancel();
    _zoomAnimationController.dispose();
    _mangaZoomController
      ..removeListener(_onMangaZoomChanged)
      ..dispose();
    WakelockPlus.disable().catchError(
      (Object e) => debugPrint('Wakelock gagal: $e'),
    );
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) _releaseReaderImageCache();
  }

  void _releaseReaderImageCache() {
    if (_readerImageCacheReleased) return;
    _readerImageCacheReleased = true;
    unawaited(_readerImageCache.close());
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
  Future<void> _loadChapterList({bool fromVpn = false}) async {
    final source = _matchedSource;
    final mangaUrl = widget.comic.sourceMangaUrl;
    if (source == null || mangaUrl == null) return;
    setState(() {
      _chaptersLoading = true;
      _chaptersError = null;
      _chaptersWebViewUrl = null;
    });
    try {
      final activeMangaUrl = rebaseSourceUrl(mangaUrl, source.baseUrl);
      final chapters = await source.fetchChapterList(activeMangaUrl);
      if (!mounted) return;
      final byUrl = widget.initialChapterUrl == null
          ? -1
          : chapters.indexWhere(
              (chapter) =>
                  sameChapterIdentity(chapter.url, widget.initialChapterUrl),
            );
      final index = byUrl != -1 ? byUrl : chapters.length - widget.chapter;
      setState(() {
        final target = (index >= 0 && index < chapters.length) ? index : 0;
        _chapters = chapters;
        _sourceChapterIndex = target;
        _chapter = chapters.length - target;
        _chaptersLoading = false;
      });
      if (activeMangaUrl != mangaUrl) {
        unawaited(
          _libraryNotifier
              .updateSourceMangaUrl(widget.comic.id, activeMangaUrl)
              .catchError(
                (Object error) => debugPrint(
                  'Gagal simpan domain baru ${widget.comic.title}: $error',
                ),
              ),
        );
      }
      _loadRealPages(fromVpn: fromVpn);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chaptersError = '$e';
        _chaptersLoading = false;
        _chaptersWebViewUrl = _resolveWebViewUrl(mangaUrl, source.baseUrl);
      });
      if (fromVpn) {
        AppToast.show(
          context,
          '🛡️ VPN telah diaktifkan · Web masih diblokir (coba WebView)',
        );
      }
    }
  }

  /// [_pagesRequestId] menjaga dari race condition: kalau pindah chapter
  /// lagi sebelum fetch chapter sebelumnya selesai, dan fetch yang lama
  /// itu (karena jaringan lambat) baru resolve BELAKANGAN, hasilnya tidak
  /// boleh menimpa `_realPages` chapter yang sedang dibuka sekarang —
  /// itu sebabnya counter/slider halaman kadang kelihatan salah/tidak
  /// sesuai chapter yang aktif.
  Future<void> _loadRealPages({bool fromVpn = false}) async {
    final source = _matchedSource;
    final index = _sourceChapterIndex;
    final chapters = _chapters;
    if (source == null || index == null || chapters == null) return;
    final requestId = ++_pagesRequestId;
    setState(() {
      _pagesLoading = true;
      _pagesError = null;
      _realPages = null;
      _pagesWebViewUrl = null;
    });
    try {
      final pages = await source.fetchPageList(chapters[index].url);
      if (!mounted || requestId != _pagesRequestId) return;
      await (_readerImageCacheReady ??= _readerImageCache.open());
      if (!mounted || requestId != _pagesRequestId) return;
      // Mulai download sementara sebelum setState membangun ImageProvider.
      // CacheManager mendeduplikasi permintaan URL yang sama dari widget.
      _readerImageCache.warmChapter(pages, center: _page);
      setState(() {
        _realPages = pages;
        _pagesLoading = false;
      });
      _precacheNearbyPages();
      if (fromVpn) {
        AppToast.show(
          context,
          '🛡️ VPN telah diaktifkan · Halaman berhasil dimuat',
        );
      }
    } catch (e) {
      if (!mounted || requestId != _pagesRequestId) return;
      setState(() {
        _pagesError = '$e';
        _pagesLoading = false;
        _pagesWebViewUrl = _resolveWebViewUrl(
          chapters[index].url,
          source.baseUrl,
        );
      });
      if (fromVpn) {
        AppToast.show(
          context,
          '🛡️ VPN telah diaktifkan · Halaman masih diblokir (coba WebView)',
        );
      }
    }
  }

  String _resolveWebViewUrl(String rawUrl, String baseUrl) {
    final value = rawUrl.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return Uri.parse(baseUrl).resolve(value).toString();
  }

  void _openReaderWebView(String initialUrl) {
    final registeredSource = ref
        .read(sourcesProvider)
        .where((source) => source.name == widget.comic.src)
        .firstOrNull;
    final matchedSource = _matchedSource;
    final fallback =
        registeredSource ??
        ComicSource(
          id: 'reader-webview-${widget.comic.id}',
          name: widget.comic.src,
          url: matchedSource?.baseUrl ?? initialUrl,
          lang: '',
          hue: widget.comic.hue,
          status: SourceStatus.webview,
        );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WebViewScreen(
          sourceId: fallback.id,
          fallbackSource: registeredSource == null ? fallback : null,
          initialUrl: initialUrl,
        ),
      ),
    );
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
          coverUrl: comic.coverUrl,
        )
        .catchError((Object e) => _reportSaveError('history', e));
    final completed = _pageCountKnown && _page + 1 >= _totalPages;
    _libraryNotifier
        .updateProgress(
          comic.id,
          read: _chapter,
          page: _page + 1,
          pages: _totalPages,
          chapterUrl: _currentChapterUrl,
          chapterLabel: _chapterLabel,
          completed: completed,
        )
        .catchError((Object e) => _reportSaveError('library', e));
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
      _precacheNearbyPages();
    }
  }

  /// Slider → scroll.
  void _seekToPage(int idx) {
    final settings = ref.read(readerSettingsProvider);
    if (!settings.isWebtoon) _resetMangaZoom();
    setState(() => _page = idx);
    _scheduleProgressSave();
    _precacheNearbyPages(center: idx);
    if (settings.isWebtoon && _scrollController.hasClients) {
      _suppressScroll = true;
      _scrollController.jumpTo(_webtoonScrollOffsetForPage(idx, settings));
      Future<void>.delayed(const Duration(milliseconds: 80), () {
        if (mounted) _suppressScroll = false;
      });
    }
  }

  double _webtoonScrollOffsetForPage(int targetPage, ReaderSettings settings) {
    final pages = _realPages;
    final width = MediaQuery.sizeOf(context).width;
    final gap = settings.gap.toDouble();
    var offset = _webtoonEdgeInset + 44.0;
    if (pages != null && pages.isNotEmpty) {
      for (var i = 0; i < targetPage && i < pages.length; i++) {
        final page = pages[i];
        final ratio = readerPageAspectRatio(
          page,
          measured: _measuredPageAspectRatios[page.imageUrl],
        );
        final height = (ratio != null && ratio > 0)
            ? (width / ratio)
            : _pageExtent(context, settings);
        offset += height + gap;
      }
    } else {
      offset += targetPage * _pageExtent(context, settings);
    }
    return offset;
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
    _resetMangaZoom();
    _clearWebtoonZoom();
    setState(() {
      _chapter = next;
      _page = 0;
      _showChrome = true;
      _pageKeys.clear();
      _precachedPageKeys.clear();
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
    _resetMangaZoom();
    _clearWebtoonZoom();
    setState(() {
      _sourceChapterIndex = newIndex;
      _chapter = chapters.length - newIndex;
      _page = 0;
      _showChrome = true;
      _pageKeys.clear();
      _precachedPageKeys.clear();
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    AppToast.show(context, chapters[newIndex].name);
    _loadRealPages();
    _scheduleProgressSave();
  }

  void _onMangaZoomChanged() {
    final scale = _mangaZoomController.value.getMaxScaleOnAxis();
    if ((_zoomRailScale.value - scale).abs() > 0.001) {
      _zoomRailScale.value = scale;
    }
    final zoomed = scale > 1.01;
    if (zoomed == _mangaZoomed || !mounted) return;
    setState(() => _mangaZoomed = zoomed);
  }

  void _resetMangaZoom() {
    _zoomAnimationController.stop();
    if (_mangaZoomController.value.isIdentity()) {
      _zoomRailScale.value = 1;
      return;
    }
    _mangaZoomController.value = Matrix4.identity();
    _zoomRailScale.value = 1;
  }

  bool get _webtoonZoomed => _webtoonZoomScale > 1.01;

  Size get _activeWebtoonViewport {
    if (!_webtoonViewportSize.isEmpty) return _webtoonViewportSize;
    return MediaQuery.sizeOf(context);
  }

  Offset _webtoonScenePointAt(Offset focalPoint) {
    final scale = math.max(1, _webtoonZoomScale);
    return Offset(
      (focalPoint.dx - _webtoonTranslation.dx) / scale,
      (focalPoint.dy - _webtoonTranslation.dy) / scale,
    );
  }

  void _applyWebtoonZoomFrame({
    required double scale,
    required Offset scenePoint,
    required Offset focalPoint,
  }) {
    final safeScale = scale.clamp(1, 5).toDouble();
    final desiredTranslation = Offset(
      focalPoint.dx - scenePoint.dx * safeScale,
      focalPoint.dy - scenePoint.dy * safeScale,
    );
    final translation = readerWebtoonPaintTranslation(
      desiredTranslation: desiredTranslation,
      scale: safeScale,
      viewport: _activeWebtoonViewport,
    );
    _webtoonZoomScale = safeScale;
    _webtoonTranslation = translation;
    _webtoonTransform.value = readerZoomMatrix(
      scale: safeScale,
      translation: translation,
    );
    _zoomRailScale.value = safeScale;
  }

  void _panWebtoonHorizontally(DragUpdateDetails details) {
    if (!_webtoonZoomed) return;
    final translation = readerWebtoonPaintTranslation(
      desiredTranslation: Offset(
        _webtoonTranslation.dx + details.delta.dx,
        _webtoonTranslation.dy,
      ),
      scale: _webtoonZoomScale,
      viewport: _activeWebtoonViewport,
    );
    _webtoonTranslation = translation;
    _webtoonTransform.value = readerZoomMatrix(
      scale: _webtoonZoomScale,
      translation: translation,
    );
  }

  void _commitWebtoonZoom(double scale) {
    final safeScale = scale.clamp(1, 5).toDouble();
    final nextInset = readerWebtoonEdgeInset(
      scale: safeScale,
      viewportHeight: _activeWebtoonViewport.height,
    );
    final insetDelta = nextInset - _webtoonEdgeInset;
    final requestId = ++_webtoonZoomRequestId;
    _webtoonDecodeTimer?.cancel();

    if (insetDelta.abs() >= 0.01 && _scrollController.hasClients) {
      final oldOffset = _scrollController.offset;
      _suppressScroll = true;
      // Hanya spacer tepi yang berubah. Offset ditambah dengan delta spacer
      // pada fase layout, jadi halaman yang sedang terlihat tidak bergeser.
      setState(() => _webtoonEdgeInset = nextInset);
      // Header/footer lazy bisa sedang tidak terpasang, sehingga perubahan
      // spacer belum tentu langsung mengubah estimasi maxScrollExtent. jumpTo
      // dilakukan sinkron sesudah setState, sebelum frame berikutnya dicat.
      _scrollController.jumpTo(math.max(0, oldOffset + insetDelta));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _suppressScroll = false;
        if (requestId != _webtoonZoomRequestId) return;
        _restoreWebtoonOffsetWithinBounds(_scrollController);
        _computeCurrentPage();
      });
    } else {
      if (insetDelta.abs() >= 0.01) {
        setState(() => _webtoonEdgeInset = nextInset);
      }
      _suppressScroll = false;
      _computeCurrentPage();
    }

    // Resolusi lebih tajam menyusul setelah gerakan selesai. Provider lama
    // tetap tampil melalui gaplessPlayback dan layout gambar tidak berubah.
    _scheduleWebtoonDecode(safeScale, requestId);
  }

  void _scheduleWebtoonDecode(double scale, int requestId) {
    _webtoonDecodeTimer?.cancel();
    if ((_webtoonDecodeScale - scale).abs() < 0.001) {
      _precacheNearbyPages();
      return;
    }
    _webtoonDecodeTimer = Timer(const Duration(milliseconds: 140), () {
      if (!mounted || requestId != _webtoonZoomRequestId) return;
      setState(() => _webtoonDecodeScale = scale);
      _precacheNearbyPages();
    });
  }

  void _restoreWebtoonOffsetWithinBounds(ScrollController controller) {
    if (!controller.hasClients) return;
    final position = controller.position;
    final target = controller.offset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - controller.offset).abs() > 0.01) {
      controller.jumpTo(target);
    }
  }

  /// Reset tanpa restorasi anchor karena pemanggil langsung pindah
  /// chapter/mode dan mengatur posisi baru sendiri.
  void _clearWebtoonZoom() {
    _zoomAnimationController.stop();
    _webtoonZoomRequestId++;
    _webtoonDecodeTimer?.cancel();
    _suppressScroll = false;
    _webtoonZoomScale = 1;
    _webtoonDecodeScale = 1;
    _webtoonEdgeInset = 0;
    _webtoonTranslation = Offset.zero;
    _webtoonTransform.value = Matrix4.identity();
    _zoomRailPreviewing = false;
    _zoomRailWebtoonSceneAnchor = null;
    _zoomRailScale.value = 1;
  }

  double _activeZoomScale(ReaderSettings settings) => settings.isWebtoon
      ? _webtoonZoomScale
      : _mangaZoomController.value.getMaxScaleOnAxis();

  void _onZoomRailChangeStart(double _) {
    _zoomAnimationController.stop();
    final settings = ref.read(readerSettingsProvider);
    final viewport = settings.isWebtoon
        ? _activeWebtoonViewport
        : MediaQuery.sizeOf(context);
    _zoomRailFocalPoint = Offset(viewport.width / 2, viewport.height / 2);
    _zoomRailStartScale = _activeZoomScale(settings).clamp(1, 5).toDouble();
    _zoomRailScale.value = _zoomRailStartScale;
    _zoomRailPreviewing = true;

    if (settings.isWebtoon) {
      _webtoonZoomRequestId++;
      _webtoonDecodeTimer?.cancel();
      _suppressScroll = true;
      _zoomRailWebtoonSceneAnchor = _webtoonScenePointAt(_zoomRailFocalPoint);
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.offset);
      }
      return;
    }

    _zoomRailMangaSceneAnchor = _mangaZoomController.toScene(
      _zoomRailFocalPoint,
    );
  }

  void _onZoomRailChanged(double rawScale) {
    if (!_zoomRailPreviewing) _onZoomRailChangeStart(rawScale);
    final settings = ref.read(readerSettingsProvider);
    final scale = rawScale.clamp(1, 5).toDouble();
    _zoomRailScale.value = scale;

    if (settings.isWebtoon) {
      final scenePoint = _zoomRailWebtoonSceneAnchor;
      if (scenePoint == null) return;
      _applyWebtoonZoomFrame(
        scale: scale,
        scenePoint: scenePoint,
        focalPoint: _zoomRailFocalPoint,
      );
      return;
    }

    final scenePoint = _zoomRailMangaSceneAnchor;
    if (scenePoint == null) return;
    _mangaZoomController.value = mangaZoomMatrixForScenePoint(
      scenePoint: scenePoint,
      focalPoint: _zoomRailFocalPoint,
      scale: scale,
    );
  }

  void _onZoomRailChangeEnd(double rawScale) {
    if (!_zoomRailPreviewing) return;
    _zoomRailPreviewing = false;
    final settings = ref.read(readerSettingsProvider);
    final scale = rawScale.clamp(1, 5).toDouble();
    _zoomRailScale.value = scale;

    if (settings.isWebtoon) {
      _zoomRailWebtoonSceneAnchor = null;
      _commitWebtoonZoom(scale);
      return;
    }

    final scenePoint = _zoomRailMangaSceneAnchor;
    _zoomRailMangaSceneAnchor = null;
    if (scenePoint == null) return;
    _mangaZoomController.value = mangaZoomMatrixForScenePoint(
      scenePoint: scenePoint,
      focalPoint: _zoomRailFocalPoint,
      scale: scale,
    );
  }

  void _cancelZoomRailPreview() {
    if (!_zoomRailPreviewing) return;
    _zoomRailPreviewing = false;
    _zoomRailWebtoonSceneAnchor = null;
    _zoomRailMangaSceneAnchor = null;
    _suppressScroll = false;
    final settings = ref.read(readerSettingsProvider);
    _zoomRailScale.value = _activeZoomScale(settings);
  }

  void _adjustZoomFromRail(double delta) {
    final settings = ref.read(readerSettingsProvider);
    final current = _activeZoomScale(settings);
    final next = (current + delta).clamp(1, 5).toDouble();
    if ((next - current).abs() < 0.001) return;
    _animateZoomTo(next);
  }

  void _resetZoomFromRail() {
    final settings = ref.read(readerSettingsProvider);
    if (_activeZoomScale(settings) <= 1.001) return;
    _animateZoomTo(1);
  }

  void _animateZoomTo(double rawTarget) {
    final settings = ref.read(readerSettingsProvider);
    final target = rawTarget.clamp(1, 5).toDouble();
    final start = _activeZoomScale(settings);
    if ((target - start).abs() < 0.001) return;

    _zoomAnimationController.stop();
    final viewport = settings.isWebtoon
        ? _activeWebtoonViewport
        : MediaQuery.sizeOf(context);
    final focal = Offset(viewport.width / 2, viewport.height / 2);
    _zoomAnimationWebtoon = settings.isWebtoon;
    _zoomAnimationStartScale = start;
    _zoomAnimationTargetScale = target;
    _zoomAnimationFocalPoint = focal;
    if (settings.isWebtoon) {
      _webtoonZoomRequestId++;
      _webtoonDecodeTimer?.cancel();
      _suppressScroll = true;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.offset);
      }
      _zoomAnimationSceneAnchor = _webtoonScenePointAt(focal);
    } else {
      _zoomAnimationSceneAnchor = _mangaZoomController.toScene(focal);
    }
    _zoomAnimationController.forward(from: 0);
  }

  void _onZoomAnimationTick() {
    if (!mounted) return;
    final progress = Curves.easeOutCubic.transform(
      _zoomAnimationController.value,
    );
    final scale =
        _zoomAnimationStartScale +
        (_zoomAnimationTargetScale - _zoomAnimationStartScale) * progress;
    if (_zoomAnimationWebtoon) {
      _applyWebtoonZoomFrame(
        scale: scale,
        scenePoint: _zoomAnimationSceneAnchor,
        focalPoint: _zoomAnimationFocalPoint,
      );
      return;
    }
    _mangaZoomController.value = mangaZoomMatrixForScenePoint(
      scenePoint: _zoomAnimationSceneAnchor,
      focalPoint: _zoomAnimationFocalPoint,
      scale: scale,
    );
    _zoomRailScale.value = scale;
  }

  void _onZoomAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    if (_zoomAnimationWebtoon) {
      _commitWebtoonZoom(_zoomAnimationTargetScale);
    } else {
      _zoomRailScale.value = _zoomAnimationTargetScale;
    }
  }

  void _onMangaTap(TapUpDetails details, bool rtl) {
    if (_mangaZoomed) {
      setState(() => _showChrome = !_showChrome);
      return;
    }
    final width = MediaQuery.sizeOf(context).width;
    if (details.localPosition.dx <= width * 0.32) {
      rtl ? _nextPage() : _prevPage();
    } else if (details.localPosition.dx >= width * 0.68) {
      rtl ? _prevPage() : _nextPage();
    } else {
      setState(() => _showChrome = !_showChrome);
    }
  }

  void _nextPage() {
    _resetMangaZoom();
    setState(() => _page = (_page + 1).clamp(0, _totalPages - 1));
    _scheduleProgressSave();
    _precacheNearbyPages();
  }

  void _prevPage() {
    _resetMangaZoom();
    setState(() => _page = (_page - 1).clamp(0, _totalPages - 1));
    _scheduleProgressSave();
    _precacheNearbyPages();
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
                webViewUrl: _chaptersWebViewUrl,
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
                webViewUrl: _pagesWebViewUrl,
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
            if (settings.sideZoomControls &&
                !_chaptersLoading &&
                _chaptersError == null &&
                !_pagesLoading &&
                _pagesError == null)
              _buildSideZoomRail(),
            if (_showChrome) ...[_buildTopToolbar(), _buildBottomToolbar()],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadError(
    String message,
    VoidCallback onRetry, {
    String? webViewUrl,
  }) {
    final vpn = ref.watch(vpnProvider);
    final isVpnEnabled = vpn.isEnabled;

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
            if (!isVpnEnabled) ...[
              InkWell(
                onTap: () async {
                  await ref.read(vpnProvider.notifier).toggle();
                  if (mounted) {
                    AppToast.show(
                      context,
                      '🛡️ VPN Kizen Diaktifkan. Memuat ulang...',
                    );
                    onRetry();
                  }
                },
                borderRadius: BorderRadius.circular(11),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.25),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.shieldCheck,
                        size: 18,
                        color: Color(0xFF10B981),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Nyalakan VPN & Muat Ulang',
                        style: AppTypography.jakarta(
                          size: 13,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
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
                  !isVpnEnabled ? 'Coba Lagi Tanpa VPN' : 'Coba Lagi',
                  style: AppTypography.jakarta(
                    size: 13,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            if (webViewUrl != null) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () => _openReaderWebView(webViewUrl),
                borderRadius: BorderRadius.circular(11),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.globe, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Buka WebView',
                        style: AppTypography.jakarta(
                          size: 13,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
    final page = pages[i];
    final stableAspectRatio = readerPageAspectRatio(
      page,
      measured: _measuredPageAspectRatios[page.imageUrl],
    );
    final decodeWidth = width * _webtoonDecodeScale;
    final imageProvider = _webtoonZoomed
        ? _webtoonZoomImageProvider(page, decodeWidth, dpr)
        : _pageImageProvider(page, width, dpr);
    // RepaintBoundary + FilterQuality.low: raster tiap halaman diisolasi
    // (scroll tidak memicu repaint halaman lain) dan digambar lebih
    // ringan di GPU — penting untuk layar refresh rate tinggi (120Hz).
    return StableReaderPageImage(
      key: ValueKey(page.imageUrl),
      imageProvider: imageProvider,
      initialAspectRatio: stableAspectRatio,
      placeholder: DecoratedBox(
        decoration: BoxDecoration(gradient: _pageGradient(i)),
        child: const Center(
          child: AppSpinner(size: 22, strokeWidth: 2, color: Colors.white),
        ),
      ),
      errorPlaceholder: _mockPageBlock(i),
      onAspectRatioKnown: (ratio) =>
          _rememberPageAspectRatio(page.imageUrl, ratio),
      onImageError: (error) {
        debugPrint(
          'Gagal memuat gambar reader: ${page.imageUrl} '
          'headers=${page.headers} error=$error',
        );
      },
    );
  }

  ImageProvider _pageImageProvider(SourcePage page, double width, double dpr) =>
      _readerImageCache.rememberProvider(
        ResizeImage.resizeIfNeeded(
          readerPageCacheWidth(page, width, dpr),
          null,
          _readerImageCache.providerFor(page),
        ),
      );

  ImageProvider _webtoonZoomImageProvider(
    SourcePage page,
    double width,
    double dpr,
  ) => _readerImageCache.rememberProvider(
    ResizeImage.resizeIfNeeded(
      readerWebtoonZoomCacheWidth(page, width, dpr),
      null,
      _readerImageCache.providerFor(page),
    ),
  );

  ImageProvider _mangaImageProvider(
    SourcePage page,
    double width,
    double dpr,
  ) => _readerImageCache.rememberProvider(
    ResizeImage.resizeIfNeeded(
      readerMangaCacheWidth(page, width, dpr),
      null,
      _readerImageCache.providerFor(page),
    ),
  );

  void _rememberPageAspectRatio(String imageUrl, double ratio) {
    if (!ratio.isFinite || ratio <= 0) return;
    // Map Dart mempertahankan insertion order. Sentuh ulang key supaya batas
    // 500 item ini bekerja seperti LRU kecil dan tidak tumbuh tanpa batas
    // kalau user membaca banyak chapter dalam satu sesi.
    _measuredPageAspectRatios.remove(imageUrl);
    _measuredPageAspectRatios[imageUrl] = ratio;
    while (_measuredPageAspectRatios.length > 500) {
      _measuredPageAspectRatios.remove(_measuredPageAspectRatios.keys.first);
    }
  }

  void _measurePageGeometry(SourcePage page, ImageProvider provider) {
    if (readerPageAspectRatio(page) != null ||
        _measuredPageAspectRatios.containsKey(page.imageUrl) ||
        _pageGeometryLoads.containsKey(page.imageUrl)) {
      return;
    }
    final stream = provider.resolve(createLocalImageConfiguration(context));
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        final ratio = info.image.width / info.image.height;
        _finishPageGeometryLoad(page.imageUrl, ratio: ratio);
      },
      onError: (Object _, StackTrace? _) {
        _finishPageGeometryLoad(page.imageUrl);
      },
    );
    _pageGeometryLoads[page.imageUrl] = _PageGeometryLoad(stream, listener);
    stream.addListener(listener);
  }

  void _finishPageGeometryLoad(String imageUrl, {double? ratio}) {
    _pageGeometryLoads.remove(imageUrl)?.dispose();
    if (ratio != null) _rememberPageAspectRatio(imageUrl, ratio);
  }

  void _precacheNearbyPages({int? center}) {
    if (!mounted) return;
    final pages = _realPages;
    if (pages == null || pages.isEmpty) return;
    final settings = ref.read(readerSettingsProvider);
    final webtoonZoomed = settings.isWebtoon && _webtoonZoomed;
    final width =
        MediaQuery.sizeOf(context).width *
        (webtoonZoomed ? _webtoonDecodeScale : 1);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final current = (center ?? _page).clamp(0, pages.length - 1);
    final start = (current - 1).clamp(0, pages.length - 1);
    final end = (current + 2).clamp(0, pages.length - 1);
    for (var i = start; i <= end; i++) {
      final page = pages[i];
      final cacheWidth = webtoonZoomed
          ? readerWebtoonZoomCacheWidth(page, width, dpr)
          : readerPageCacheWidth(page, width, dpr);
      final key = '${page.imageUrl}@$cacheWidth';
      if (!_precachedPageKeys.add(key)) continue;
      final provider = webtoonZoomed
          ? _webtoonZoomImageProvider(page, width, dpr)
          : _pageImageProvider(page, width, dpr);
      _measurePageGeometry(page, provider);
      precacheImage(provider, context).catchError((Object e) {
        _precachedPageKeys.remove(key);
        debugPrint('Precache gambar reader gagal: $e');
      });
    }
  }

  Widget _buildWebtoon(ReaderSettings settings) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        _webtoonViewportSize = viewport;
        final width = constraints.maxWidth;
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final list = ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.zero,
          clipBehavior: Clip.none,
          scrollCacheExtent: const ScrollCacheExtent.viewport(2.0),
          itemCount: _totalPages + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return SizedBox(height: _webtoonEdgeInset + 44);
            }
            if (index == _totalPages + 1) {
              return GestureDetector(
                onTap: () => _changeChapter(1),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    40,
                    20,
                    60 + _webtoonEdgeInset,
                  ),
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

        // Seperti WebtoonRecyclerView Mihon: daftar tetap berukuran asli dan
        // hanya layer paint yang diskalakan. Tidak ada relayout ratusan strip,
        // pergantian ScrollPosition, atau reset provider saat nilai zoom berubah.
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: _panWebtoonHorizontally,
          child: ClipRect(
            key: _viewportKey,
            child: ValueListenableBuilder<Matrix4>(
              valueListenable: _webtoonTransform,
              child: RepaintBoundary(child: list),
              builder: (context, matrix, child) => Transform(
                key: const ValueKey('reader-webtoon-transform'),
                transform: matrix,
                alignment: Alignment.topLeft,
                filterQuality: FilterQuality.low,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildManga(ReaderSettings settings) {
    final rtl = settings.direction == ReadingDirection.rtl;
    final pages = _realPages;
    final isReal = pages != null && _page < pages.length;
    final width = MediaQuery.sizeOf(context).width;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => _onMangaTap(details, rtl),
      child: InteractiveViewer(
        transformationController: _mangaZoomController,
        minScale: 1,
        maxScale: 5,
        panEnabled: _mangaZoomed,
        scaleEnabled: false,
        boundaryMargin: const EdgeInsets.all(96),
        clipBehavior: Clip.hardEdge,
        child: SizedBox.expand(
          child: Center(
            child: isReal
                ? RepaintBoundary(
                    child: Image(
                      key: ValueKey(pages[_page].imageUrl),
                      image: _mangaImageProvider(pages[_page], width, dpr),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
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
                      errorBuilder: (_, error, _) {
                        debugPrint(
                          'Gagal memuat gambar reader: '
                          '${pages[_page].imageUrl} '
                          'headers=${pages[_page].headers} error=$error',
                        );
                        return AspectRatio(
                          aspectRatio: AppDimens.coverAspectRatio,
                          child: _mockPageBlock(_page, large: true),
                        );
                      },
                    ),
                  )
                : AspectRatio(
                    aspectRatio: AppDimens.coverAspectRatio,
                    child: _mockPageBlock(_page, large: true),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSideZoomRail() {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 88,
      right: 8,
      bottom: MediaQuery.paddingOf(context).bottom + 154,
      child: Center(
        child: GestureDetector(
          key: const ValueKey('reader-zoom-rail'),
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xE0141820),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x29FFFFFF)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ValueListenableBuilder<double>(
              valueListenable: _zoomRailScale,
              builder: (context, scale, _) {
                final normalized = scale.clamp(1, 5).toDouble();
                return SizedBox(
                  width: 48,
                  height: 250,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        key: const ValueKey('reader-zoom-in'),
                        tooltip: 'Perbesar',
                        visualDensity: VisualDensity.compact,
                        onPressed: normalized >= 4.999
                            ? null
                            : () => _adjustZoomFromRail(0.25),
                        icon: const Icon(LucideIcons.zoomIn, size: 18),
                        color: Colors.white,
                        disabledColor: Colors.white30,
                      ),
                      SizedBox(
                        height: 18,
                        child: Text(
                          '${(normalized * 100).round()}%',
                          textAlign: TextAlign.center,
                          style:
                              AppTypography.jakarta(
                                size: 9.5,
                                weight: FontWeight.w700,
                                color: AppColors.accentText,
                              ).copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ),
                      SizedBox(
                        key: const ValueKey('reader-zoom-slider'),
                        width: 40,
                        height: 104,
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: SliderTheme(
                            data: const SliderThemeData(
                              trackHeight: 3,
                              activeTrackColor: AppColors.accent,
                              inactiveTrackColor: Color(0x33FFFFFF),
                              thumbColor: Colors.white,
                              overlayColor: Color(0x3350B8E8),
                              thumbShape: RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              overlayShape: RoundSliderOverlayShape(
                                overlayRadius: 13,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                            child: Slider(
                              value: normalized,
                              min: 1,
                              max: 5,
                              onChangeStart: _onZoomRailChangeStart,
                              onChanged: _onZoomRailChanged,
                              onChangeEnd: _onZoomRailChangeEnd,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('reader-zoom-out'),
                        tooltip: 'Perkecil',
                        visualDensity: VisualDensity.compact,
                        onPressed: normalized <= 1.001
                            ? null
                            : () => _adjustZoomFromRail(-0.25),
                        icon: const Icon(LucideIcons.zoomOut, size: 18),
                        color: Colors.white,
                        disabledColor: Colors.white30,
                      ),
                      SizedBox(
                        width: 28,
                        child: Divider(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('reader-zoom-reset'),
                        tooltip: 'Reset zoom',
                        visualDensity: VisualDensity.compact,
                        onPressed: normalized <= 1.001
                            ? null
                            : _resetZoomFromRail,
                        icon: const Icon(LucideIcons.rotateCcw, size: 17),
                        color: AppColors.accentText,
                        disabledColor: Colors.white30,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
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
              colors: [
                Color(0xF506070B),
                Color(0xBF06070B),
                Color(0x4006070B),
                Colors.transparent,
              ],
              stops: [0.0, 0.5, 0.8, 1.0],
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
              const SizedBox(width: 8),
              KizenVpnQuickButton(
                compact: true,
                onToggled: (enabled) {
                  if (enabled) {
                    if (_pagesError != null || _chaptersError != null) {
                      if (_pagesError != null) _loadRealPages(fromVpn: true);
                      if (_chaptersError != null) _loadChapterList(fromVpn: true);
                    } else {
                      _loadRealPages(fromVpn: true);
                    }
                  }
                },
              ),
              const SizedBox(width: 8),
              _chromeButton(
                size: 38,
                icon: _isCurrentPageBookmarked()
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                active: _isCurrentPageBookmarked(),
                onTap: _toggleBookmark,
              ),
              const SizedBox(width: 8),
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
              colors: [
                Color(0xF806070B),
                Color(0xCC06070B),
                Color(0x4006070B),
                Colors.transparent,
              ],
              stops: [0.0, 0.5, 0.85, 1.0],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xEB12141D),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                        width: 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      _pageCountKnown ? '${_page + 1} / $_totalPages' : '–',
                      style:
                          AppTypography.jakarta(
                            size: 11.5,
                            weight: FontWeight.w600,
                            color: Colors.white,
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
                        color: const Color(0xEB12141D),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                          width: 1.1,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x77000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
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
          color: const Color(0xEB12141D),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.16),
            width: 1.1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x77000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
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
    String? tooltip,
  }) {
    final button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.35)
              : const Color(0xEB12141D),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: active
                ? AppColors.accent.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.16),
            width: 1.1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x77000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 19,
          color: active ? AppColors.accentText : Colors.white,
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
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
    return ref
        .watch(bookmarksProvider)
        .any(
          (entry) =>
              entry.page == _page + 1 &&
              BookmarksNotifier.matchesChapter(
                entry,
                comicId: comic.id,
                chapterNum: _chapter,
                chapterUrl: _currentChapterUrl,
              ),
        );
  }

  /// Tandai/lepas halaman yang lagi dibuka sebagai bookmark ("momen
  /// epic") — beda dari progres baca biasa, tidak ketimpa/hilang saat
  /// lanjut baca, dan bisa banyak per komik lewat [_openBookmarks].
  void _toggleBookmark() {
    final comic = widget.comic;
    final wasBookmarked = ref
        .read(bookmarksProvider)
        .any(
          (entry) =>
              entry.page == _page + 1 &&
              BookmarksNotifier.matchesChapter(
                entry,
                comicId: comic.id,
                chapterNum: _chapter,
                chapterUrl: _currentChapterUrl,
              ),
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
    _resetMangaZoom();
    _clearWebtoonZoom();
    if (_isRealSource) {
      final chapters = _chapters;
      if (chapters == null) return; // daftar chapter belum selesai di-fetch
      final byUrl = item.chapterUrl == null
          ? -1
          : chapters.indexWhere(
              (chapter) => sameChapterIdentity(chapter.url, item.chapterUrl),
            );
      final targetIndex = byUrl != -1 ? byUrl : chapters.length - item.chNum;
      if (targetIndex < 0 || targetIndex >= chapters.length) return;
      setState(() {
        _sourceChapterIndex = targetIndex;
        _chapter = chapters.length - targetIndex;
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
    final initial = ref.read(readerSettingsProvider);
    var direction = initial.direction;
    var sideZoomControls = initial.sideZoomControls;
    showReaderSettingsSheet(
      context,
      onChanged: () {
        _applyWakelock();
        final next = ref.read(readerSettingsProvider);
        final nextDirection = next.direction;
        if (nextDirection != direction) {
          _cancelZoomRailPreview();
          direction = nextDirection;
          _resetMangaZoom();
          setState(_clearWebtoonZoom);
        }
        if (next.sideZoomControls != sideZoomControls) {
          sideZoomControls = next.sideZoomControls;
          _cancelZoomRailPreview();
          if (!next.sideZoomControls) {
            _resetMangaZoom();
            setState(_clearWebtoonZoom);
          } else {
            _zoomRailScale.value = _activeZoomScale(next);
          }
        }
      },
    );
  }
}

class _PageGeometryLoad {
  const _PageGeometryLoad(this.stream, this.listener);

  final ImageStream stream;
  final ImageStreamListener listener;

  void dispose() => stream.removeListener(listener);
}

/// Image reader yang mempertahankan tinggi stabil selama widget lazy-list
/// dibuang lalu dibuat ulang. Rasio hasil decode dikirim ke parent agar tetap
/// tersedia walaupun bitmap-nya sudah dikeluarkan dari ImageCache.
class StableReaderPageImage extends StatefulWidget {
  const StableReaderPageImage({
    super.key,
    required this.imageProvider,
    required this.placeholder,
    required this.errorPlaceholder,
    required this.onAspectRatioKnown,
    required this.onImageError,
    this.initialAspectRatio,
  });

  final ImageProvider imageProvider;
  final Widget placeholder;
  final Widget errorPlaceholder;
  final double? initialAspectRatio;
  final ValueChanged<double> onAspectRatioKnown;
  final ValueChanged<Object> onImageError;

  @override
  State<StableReaderPageImage> createState() => _StableReaderPageImageState();
}

class _StableReaderPageImageState extends State<StableReaderPageImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  double? _aspectRatio;
  bool _hasFrame = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stream == null && !_hasFrame) _resolveImage();
  }

  @override
  void didUpdateWidget(covariant StableReaderPageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageProvider != oldWidget.imageProvider) {
      // Jangan buang rasio/frame lama saat zoom meminta ukuran decode baru.
      // Image dengan gaplessPlayback akan mempertahankannya sampai frame tajam
      // siap, jadi halaman tidak berkedip menjadi spinner/blank.
      _resolveImage();
      return;
    }
    final initial = _validAspectRatio(widget.initialAspectRatio);
    if (initial != null && initial != _aspectRatio) {
      _stopListening();
      _aspectRatio = initial;
    }
  }

  void _resolveImage() {
    _stopListening();
    _aspectRatio ??= _validAspectRatio(widget.initialAspectRatio);

    final stream = widget.imageProvider.resolve(
      createLocalImageConfiguration(context),
    );
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, synchronousCall) {
      final ratio = _validAspectRatio(info.image.width / info.image.height);
      if (ratio == null) return;
      widget.onAspectRatioKnown(ratio);
      final firstFrame = !_hasFrame;
      _hasFrame = true;
      if (synchronousCall) {
        _aspectRatio = ratio;
      } else if (mounted && (firstFrame || _aspectRatio != ratio)) {
        setState(() => _aspectRatio = ratio);
      }
      _stopListening();
    }, onError: (Object _, StackTrace? _) => _stopListening());
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  double? _validAspectRatio(double? value) {
    if (value == null || !value.isFinite || value <= 0) return null;
    return value;
  }

  void _stopListening() {
    final stream = _stream;
    final listener = _listener;
    if (stream != null && listener != null) stream.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: _aspectRatio ?? 0.7,
        child: Image(
          image: widget.imageProvider,
          fit: BoxFit.contain,
          alignment: Alignment.topCenter,
          filterQuality: FilterQuality.low,
          gaplessPlayback: true,
          loadingBuilder: (context, child, progress) =>
              progress == null || _hasFrame ? child : widget.placeholder,
          errorBuilder: (_, error, _) {
            widget.onImageError(error);
            return widget.errorPlaceholder;
          },
        ),
      ),
    );
  }
}

/// Rasio metadata atau hasil decode dipakai untuk memesan tinggi halaman
/// sebelum image selesai dimuat ulang. Ini mencegah strip webtoon yang sangat
/// panjang menyusut jadi placeholder pendek saat pengguna scroll balik ke atas.
@visibleForTesting
double? readerPageAspectRatio(SourcePage page, {double? measured}) {
  final width = page.width;
  final height = page.height;
  if (width != null && height != null && width > 0 && height > 0) {
    return width / height;
  }
  if (measured == null || !measured.isFinite || measured <= 0) return null;
  return measured;
}

/// Decode tidak pernah dibuat lebih lebar dari file asli. Sebelumnya gambar
/// 800px bisa di-upscale ke lebar DPR 1200px saat decode, memboroskan puluhan
/// MB per strip dan membuat halaman lama cepat terlempar dari ImageCache.
@visibleForTesting
int readerPageCacheWidth(SourcePage page, double width, double dpr) {
  final imageWidth = page.width;
  final imageHeight = page.height;
  final target = math.max(1.0, width * dpr);
  if (imageWidth == null ||
      imageHeight == null ||
      imageWidth <= 0 ||
      imageHeight <= 0) {
    return target.round();
  }
  final aspectRatio = imageWidth / imageHeight;
  const maxDecodedHeight = 12000.0;
  final cappedByHeight = maxDecodedHeight * aspectRatio;
  return math
      .max(
        1.0,
        math.min(target, math.min(imageWidth.toDouble(), cappedByHeight)),
      )
      .round();
}

/// Mode halaman menyimpan resolusi lebih tinggi daripada lebar layar karena
/// rail bisa memperbesar sampai 5x. Tetap dibatasi lebar file asli (kalau metadata
/// tersedia) dan 4096px supaya satu halaman manga tidak memicu OOM.
@visibleForTesting
int readerMangaCacheWidth(SourcePage page, double width, double dpr) {
  const maxDecodedWidth = 4096.0;
  final zoomReadyTarget = math.max(1.0, width * dpr * 2);
  final originalWidth = page.width;
  final bounded = originalWidth != null && originalWidth > 0
      ? math.min(zoomReadyTarget, originalWidth.toDouble())
      : zoomReadyTarget;
  return math.min(maxDecodedWidth, bounded).round();
}

/// Zoom webtoon boleh meminta bitmap lebih tajam daripada mode 1x, tetapi
/// strip vertikal jauh lebih tinggi daripada halaman manga biasa. Batas 2048
/// px mencegah satu strip tanpa metadata didecode menjadi bitmap raksasa.
@visibleForTesting
int readerWebtoonZoomCacheWidth(SourcePage page, double width, double dpr) {
  const maxDecodedWidth = 2048;
  return math.min(maxDecodedWidth, readerPageCacheWidth(page, width, dpr));
}

/// Spacer simetris memberi ruang buat mencapai ujung awal/akhir chapter ketika
/// viewport diskalakan terhadap titik tengah. Hanya spacer ini yang dilayout
/// ulang saat slider dilepas; ukuran seluruh halaman tetap asli.
@visibleForTesting
double readerWebtoonEdgeInset({
  required double scale,
  required double viewportHeight,
}) {
  if (!scale.isFinite || scale <= 1 || !viewportHeight.isFinite) return 0;
  return math.max(0, viewportHeight) * (1 - 1 / scale) / 2;
}

/// Membatasi hasil pan supaya layer webtoon selalu menutup viewport. Tidak ada
/// scroll/layout horizontal tambahan; pan hanya mengubah translasi GPU.
@visibleForTesting
Offset readerWebtoonPaintTranslation({
  required Offset desiredTranslation,
  required double scale,
  required Size viewport,
}) {
  final safeScale = scale.isFinite ? scale.clamp(1.0, 5.0).toDouble() : 1.0;
  if (safeScale <= 1 || viewport.isEmpty) return Offset.zero;
  final minX = viewport.width * (1 - safeScale);
  final minY = viewport.height * (1 - safeScale);
  final rawX = desiredTranslation.dx.isFinite ? desiredTranslation.dx : 0.0;
  final rawY = desiredTranslation.dy.isFinite ? desiredTranslation.dy : 0.0;
  return Offset(rawX.clamp(minX, 0).toDouble(), rawY.clamp(minY, 0).toDouble());
}

/// Matriks paint-only yang dipakai webtoon dan mode halaman. Karena layout
/// gambar tidak berubah, slider cukup mengubah satu layer kompositor.
@visibleForTesting
Matrix4 readerZoomMatrix({required double scale, required Offset translation}) {
  final safeScale = scale.isFinite ? scale.clamp(1.0, 5.0).toDouble() : 1.0;
  return Matrix4.identity()
    ..translateByDouble(translation.dx, translation.dy, 0, 1)
    ..scaleByDouble(safeScale, safeScale, 1, 1);
}

/// Matrix zoom yang mempertahankan titik fokus pada posisi yang sama.
@visibleForTesting
Matrix4 mangaZoomMatrix({required Offset focalPoint, required double scale}) {
  return mangaZoomMatrixForScenePoint(
    scenePoint: focalPoint,
    focalPoint: focalPoint,
    scale: scale,
  );
}

/// Matrix absolut buat rail zoom mode Halaman. [scenePoint] adalah titik
/// gambar yang sedang berada di bawah [focalPoint], jadi perubahan skala tidak
/// membuang pan yang sudah dilakukan user.
@visibleForTesting
Matrix4 mangaZoomMatrixForScenePoint({
  required Offset scenePoint,
  required Offset focalPoint,
  required double scale,
}) {
  final safeScale = scale.clamp(1.0, 5.0).toDouble();
  return readerZoomMatrix(
    scale: safeScale,
    translation: Offset(
      focalPoint.dx - scenePoint.dx * safeScale,
      focalPoint.dy - scenePoint.dy * safeScale,
    ),
  );
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
