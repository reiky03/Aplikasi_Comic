import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/library_state.dart';
import '../../data/models.dart';
import '../../data/sources_state.dart';
import '../../sources/manga_source.dart';
import '../../sources/source_catalog.dart';
import '../detail/comic_detail_screen.dart';
import 'add_source_screen.dart';
import 'web_view_screen.dart';

enum _DiscoverTab { popular, latest, search }

/// Source Detail — spek 10: grid discover (parsable) / error state + WebView.
class SourceDetailScreen extends ConsumerStatefulWidget {
  const SourceDetailScreen({
    super.key,
    required this.sourceId,
    this.fallbackSource,
  });

  final String sourceId;

  /// Untuk sumber sintetis dari repository (tidak ada di sourcesProvider).
  final ComicSource? fallbackSource;

  @override
  ConsumerState<SourceDetailScreen> createState() => _SourceDetailScreenState();
}

class _SourceDetailScreenState extends ConsumerState<SourceDetailScreen> {
  _DiscoverTab _tab = _DiscoverTab.popular;
  String _search = '';
  bool _refreshing = false;
  bool _retrying = false;
  final _searchController = TextEditingController();

  MangaSource? _matchedSource;
  bool _discoverLoading = false;
  String? _discoverError;
  List<Comic> _discoverResults = const [];
  Timer? _searchDebounce;

  // Paginasi grid discover — sebelumnya cuma pernah fetch halaman 1 dan
  // tidak pernah nambah lagi biar pun di-refresh, jadi kelihatan "isinya
  // segitu-segitu aja" walau sumbernya sebenarnya punya ratusan judul.
  int _discoverPage = 1;
  bool _hasNextPage = true;
  bool _loadingMore = false;
  final _gridScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _gridScrollController.addListener(_onGridScroll);
    final source =
        ref
            .read(sourcesProvider)
            .where((s) => s.id == widget.sourceId)
            .firstOrNull ??
        widget.fallbackSource;
    if (source != null) {
      // Coba 4 sumber native dulu, baru parser tema generik yang sudah
      // ke-auto-detect saat sumber ini ditambahkan (lihat
      // `ComicSource.parserKind` & `add_source_screen.dart`) — supaya
      // sumber custom juga bisa nampilin grid discover, bukan cuma
      // fallback ke WebView.
      _matchedSource =
          SourceCatalog.matchByUrl(source.url) ??
          (source.parserKind != null
              ? SourceCatalog.buildGeneric(
                  source.parserKind!,
                  source.name,
                  'https://${source.url}',
                )
              : null);
      if (_matchedSource != null) _loadDiscover(source);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    _gridScrollController.dispose();
    super.dispose();
  }

  /// Dekat dasar grid (600px tersisa) → ambil halaman berikutnya otomatis.
  void _onGridScroll() {
    if (!_gridScrollController.hasClients) return;
    final pos = _gridScrollController.position;
    if (pos.maxScrollExtent - pos.pixels < 600) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _discoverLoading || !_hasNextPage) return;
    final matched = _matchedSource;
    final source = _source;
    if (matched == null || source == null) return;
    if (_tab == _DiscoverTab.search && _search.trim().isEmpty) return;
    setState(() => _loadingMore = true);
    final nextPage = _discoverPage + 1;
    try {
      final result = switch (_tab) {
        _DiscoverTab.popular => await matched.fetchPopular(nextPage),
        _DiscoverTab.latest => await matched.fetchLatest(nextPage),
        _DiscoverTab.search => await matched.fetchSearch(
          _search.trim(),
          nextPage,
        ),
      };
      if (!mounted) return;
      setState(() {
        _discoverResults = [
          ..._discoverResults,
          ...result.mangas.map((m) => _toComic(source, m)),
        ];
        _discoverPage = nextPage;
        _hasNextPage = result.hasNextPage;
        _loadingMore = false;
      });
    } catch (_) {
      // Diam-diam gagal — yang sudah kemuat tetap ditampilkan, biarkan
      // scroll ke bawah lagi jadi pemicu buat coba lagi.
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  ComicSource? get _source {
    final sources = ref.watch(sourcesProvider);
    for (final s in sources) {
      if (s.id == widget.sourceId) return s;
    }
    return widget.fallbackSource;
  }

  Comic _toComic(ComicSource source, SourceManga m) => Comic(
    id: 'src_${source.id}_${Uri.encodeComponent(m.url)}',
    title: m.title,
    src: source.name,
    hue: source.hue,
    ch: 0,
    coverUrl: m.thumbnailUrl,
    sourceMangaUrl: m.url,
  );

  /// Ambil daftar komik ASLI dari sumber yang punya parser native (lihat
  /// lib/sources/) sesuai tab aktif. Sumber di luar daftar tetap pakai
  /// daftar demo statis (lihat [_discoverItems]) — tidak berubah.
  Future<void> _loadDiscover(ComicSource source, {int page = 1}) async {
    final matched = _matchedSource;
    if (matched == null) return;
    if (_tab == _DiscoverTab.search && _search.trim().isEmpty) {
      setState(() {
        _discoverResults = const [];
        _discoverLoading = false;
        _discoverError = null;
        _hasNextPage = false;
      });
      return;
    }
    setState(() {
      _discoverLoading = true;
      _discoverError = null;
    });
    try {
      final result = switch (_tab) {
        _DiscoverTab.popular => await matched.fetchPopular(page),
        _DiscoverTab.latest => await matched.fetchLatest(page),
        _DiscoverTab.search => await matched.fetchSearch(_search.trim(), page),
      };
      if (!mounted) return;
      setState(() {
        _discoverResults = result.mangas
            .map((m) => _toComic(source, m))
            .toList();
        _discoverPage = page;
        _hasNextPage = result.hasNextPage;
        _discoverLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _discoverError = '$e';
        _discoverLoading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _search = value);
    if (_matchedSource == null || _tab != _DiscoverTab.search) return;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      final source = _source;
      if (source != null) _loadDiscover(source);
    });
  }

  void _switchTab(_DiscoverTab tab) {
    setState(() => _tab = tab);
    final source = _source;
    if (_matchedSource != null && source != null) _loadDiscover(source);
  }

  /// Refresh daftar komik. Sumber dengan parser native: fetch ulang
  /// sungguhan. Sumber lain: simulasi prototipe ~1.1s.
  Future<void> _refresh() async {
    if (_refreshing) return;
    final source = _source;
    if (_matchedSource != null && source != null) {
      setState(() => _refreshing = true);
      await _loadDiscover(source);
      if (!mounted) return;
      setState(() => _refreshing = false);
      AppToast.show(context, 'Daftar komik diperbarui');
      return;
    }
    setState(() => _refreshing = true);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    setState(() => _refreshing = false);
    AppToast.show(context, 'Daftar komik diperbarui');
  }

  /// Coba parse ulang. Timing prototipe ~1.3s (selalu gagal di demo).
  /// TODO(backend): retry parse sungguhan.
  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    setState(() => _retrying = false);
    AppToast.show(context, 'Masih belum bisa dibaca otomatis — coba WebView');
  }

  void _openWebView(ComicSource source) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WebViewScreen(sourceId: source.id),
      ),
    );
  }

  void _resetSession(ComicSource source) {
    ref.read(sourcesProvider.notifier).setSession(source.id, false);
    AppToast.show(context, 'Session di-reset untuk ${source.name}');
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    if (source == null) {
      // Sumber dihapus saat layar terbuka — kembali.
      return const Scaffold(backgroundColor: AppColors.bg, body: SizedBox());
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Row(
                children: [
                  AppBackButton(onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          source.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.jakarta(
                            size: 18,
                            weight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          source.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.mono(
                            size: 11.5,
                            color: AppColors.textFaintestAlt,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Buka situs asli lewat WebView — jalan pintas kalau
                  // parser gagal/situs berubah struktur, tanpa harus
                  // nunggu status source berubah jadi "gagal" dulu.
                  AppHeaderIconButton(
                    icon: LucideIcons.globe,
                    onTap: () => _openWebView(source),
                  ),
                  const SizedBox(width: 10),
                  if (_refreshing)
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const AppSpinner(
                        size: 17,
                        strokeWidth: 2,
                        color: AppColors.menuIcon,
                      ),
                    )
                  else
                    AppHeaderIconButton(
                      icon: LucideIcons.rotateCw,
                      onTap: _refresh,
                    ),
                ],
              ),
            ),
            Expanded(
              child: source.readable
                  ? _buildParsable(source)
                  : _buildErrorState(source),
            ),
          ],
        ),
      ),
    );
  }

  // --- State A: parsable ---

  Widget _buildParsable(ComicSource source) {
    final libraryIds = ref.watch(libraryProvider).map((c) => c.id).toSet();
    final List<Comic> items;
    if (_matchedSource != null) {
      items = _discoverResults;
    } else {
      final discover = _discoverItems(source);
      final q = _search.trim().toLowerCase();
      items = _tab == _DiscoverTab.search && q.isNotEmpty
          ? discover.where((c) => c.title.toLowerCase().contains(q)).toList()
          : discover;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (source.session)
          Container(
            margin: const EdgeInsets.fromLTRB(18, 2, 18, 6),
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 13),
            decoration: BoxDecoration(
              color: const Color(0x1434D399),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0x4034D399)),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.lock,
                  size: 17,
                  color: AppColors.success,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session aktif',
                        style: AppTypography.jakarta(
                          size: 12.5,
                          weight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                      Text(
                        'Dibuka via WebView · reader mode aktif',
                        style: AppTypography.jakarta(
                          size: 11,
                          weight: FontWeight.w400,
                          color: const Color(0xFF7D9B8C),
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _resetSession(source),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: const Color(0x59FF7A93)),
                    ),
                    child: Text(
                      'Reset',
                      style: AppTypography.jakarta(
                        size: 11.5,
                        weight: FontWeight.w700,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  AppIcons.search,
                  size: 17,
                  color: AppColors.textFaint,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    cursorColor: AppColors.accent,
                    style: AppTypography.jakarta(
                      size: 13.5,
                      weight: FontWeight.w400,
                    ),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'Cari komik di ${source.name}…',
                      hintStyle: AppTypography.jakarta(
                        size: 13.5,
                        weight: FontWeight.w400,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              _discoverTab('Populer', _DiscoverTab.popular),
              const SizedBox(width: 22),
              _discoverTab('Terbaru', _DiscoverTab.latest),
              const SizedBox(width: 22),
              _discoverTab('Hasil Cari', _DiscoverTab.search),
            ],
          ),
        ),
        Expanded(
          child: _matchedSource != null && _discoverLoading
              ? const Center(child: AppSpinner(size: 28, strokeWidth: 2.5))
              : _matchedSource != null && _discoverError != null
              ? _buildDiscoverError(source)
              : items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(30, 40, 30, 0),
                  child: Text(
                    _tab == _DiscoverTab.search && _search.trim().isEmpty
                        ? 'Ketik judul untuk mencari'
                        : 'Tidak ada hasil untuk pencarian ini',
                    textAlign: TextAlign.center,
                    style: AppTypography.jakarta(
                      size: 14,
                      weight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : Stack(
                  children: [
                    GridView.builder(
                      controller: _gridScrollController,
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 40),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: AppDimens.gridColumns,
                            crossAxisSpacing: AppDimens.gridGap,
                            mainAxisSpacing: AppDimens.gridGap,
                            childAspectRatio: 0.52,
                          ),
                      itemCount: items.length,
                      itemBuilder: (context, i) => _DiscoverCard(
                        key: ValueKey(items[i].id),
                        comic: items[i],
                        inLibrary: libraryIds.contains(items[i].id),
                        onTap: () => _openComic(items[i]),
                      ),
                    ),
                    if (_loadingMore)
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 10,
                        child: Center(
                          child: AppSpinner(size: 22, strokeWidth: 2.5),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildDiscoverError(ComicSource source) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 40, 30, 0),
      child: Column(
        children: [
          Text(
            'Gagal memuat daftar komik.\n${_discoverError ?? ''}',
            textAlign: TextAlign.center,
            style: AppTypography.jakarta(
              size: 13,
              weight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () => _loadDiscover(source),
            borderRadius: BorderRadius.circular(11),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: AppColors.borderStrong),
              ),
              child: Text(
                'Coba Lagi',
                style: AppTypography.jakarta(
                  size: 13,
                  weight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _discoverTab(String label, _DiscoverTab tab) {
    final active = _tab == tab;
    return InkWell(
      onTap: () => _switchTab(tab),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 2,
              color: active ? AppColors.accent : Colors.transparent,
            ),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.jakarta(
            size: 13.5,
            weight: FontWeight.w700,
            color: active ? Colors.white : AppColors.textFaint,
          ),
        ),
      ),
    );
  }

  /// Set discover demo prototipe: 9 judul, hue turunan sumber.
  List<Comic> _discoverItems(ComicSource source) {
    const titles = [
      'Void Chronicles',
      'Iron Petals',
      'Ghostlight',
      'Duskbound',
      'Ember & Ash',
      'Paper Moon',
      'Silent Harbor',
      'Wildcard',
      'Nova Drift',
    ];
    return [
      for (var i = 0; i < titles.length; i++)
        Comic(
          id: 'd$i',
          title: titles[i],
          src: source.name,
          hue: (source.hue + i * 33) % 360,
          ch: 20 + i * 7,
        ),
    ];
  }

  void _openComic(Comic comic) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ComicDetailScreen(comic: comic)),
    );
  }

  // --- State B: error / butuh WebView ---

  Widget _buildErrorState(ComicSource source) {
    final status = source.statusMeta;
    final message = switch (source.status) {
      SourceStatus.failed =>
        'Source gagal diakses. Website mungkin sedang down atau memblokir '
            'akses jaringan. Coba lagi, atau buka lewat WebView untuk membuat '
            'sesi.',
      SourceStatus.limited =>
        'Akses ke source ini terbatas. Sebagian halaman mungkin meminta '
            'verifikasi browser. Buka lewat WebView untuk membuka sesi penuh.',
      _ =>
        'Source ini tidak bisa dibaca otomatis. Website mungkin membutuhkan '
            'verifikasi browser atau memiliki proteksi akses. Kamu bisa '
            'membukanya lewat WebView terlebih dahulu.',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 60),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.sheetTopBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: status.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  'Status: ${status.label}',
                  style: AppTypography.jakarta(
                    size: 11.5,
                    weight: FontWeight.w700,
                    color: status.color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: status.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            child: Icon(LucideIcons.lock, size: 38, color: status.color),
          ),
          const SizedBox(height: 16),
          Text(
            'Tidak bisa dibaca otomatis',
            style: AppTypography.jakarta(size: 16.5, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.jakarta(
                size: 13.5,
                weight: FontWeight.w400,
                height: 1.55,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 22),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 290),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _primaryAction(
                  label: 'Buka lewat WebView',
                  icon: LucideIcons.globe,
                  onTap: () => _openWebView(source),
                ),
                const SizedBox(height: 9),
                _outlineAction(
                  onTap: _retry,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_retrying) ...[
                        const AppSpinner(
                          size: 15,
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text('Mencoba…', style: _outlineLabel(Colors.white)),
                      ] else ...[
                        const Icon(
                          LucideIcons.rotateCw,
                          size: 17,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Coba Lagi',
                          style: _outlineLabel(AppColors.textPrimary),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 9),
                _outlineAction(
                  onTap: () => AppToast.show(context, 'Membuka di browser…'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        LucideIcons.externalLink,
                        size: 17,
                        color: AppColors.menuIcon,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Buka di Browser',
                        style: _outlineLabel(AppColors.menuIcon),
                      ),
                    ],
                  ),
                ),
                if (source.session) ...[
                  const SizedBox(height: 9),
                  InkWell(
                    onTap: () => _resetSession(source),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 46,
                      alignment: Alignment.center,
                      child: Text(
                        'Reset Session',
                        style: AppTypography.jakarta(
                          size: 13.5,
                          weight: FontWeight.w700,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              'Kizen tidak melakukan bypass otomatis. WebView memakai sesi '
              'normal yang kamu buat sendiri.',
              textAlign: TextAlign.center,
              style: AppTypography.jakarta(
                size: 11,
                weight: FontWeight.w400,
                height: 1.5,
                color: AppColors.textFaintest,
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _outlineLabel(Color color) =>
      AppTypography.jakarta(size: 14.5, weight: FontWeight.w700, color: color);

  Widget _primaryAction({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(label, style: _outlineLabel(Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _outlineAction({required Widget child, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x1FFFFFFF)), // .12
        ),
        child: child,
      ),
    );
  }
}

/// Kartu grid discover (tanpa caption "Ch. N", inisial 48px).
class _DiscoverCard extends StatelessWidget {
  const _DiscoverCard({
    super.key,
    required this.comic,
    required this.onTap,
    this.inLibrary = false,
  });

  final Comic comic;
  final VoidCallback onTap;

  /// true kalau komik ini sudah tersimpan di Library user.
  final bool inLibrary;

  @override
  Widget build(BuildContext context) {
    // Sama seperti ComicGridCard (Library) — decode sesuai ukuran sel
    // tampil, bukan resolusi asli, biar scroll grid discover tetap ringan.
    final cellWidth =
        (MediaQuery.sizeOf(context).width -
            36 -
            AppDimens.gridGap * (AppDimens.gridColumns - 1)) /
        AppDimens.gridColumns;
    final cacheWidth = (cellWidth * MediaQuery.devicePixelRatioOf(context))
        .round();
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: AppDimens.coverAspectRatio,
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
                      initial: comic.initial,
                      fontSize: 48,
                      cacheWidth: cacheWidth,
                    ),
                    if (inLibrary)
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x66000000),
                                offset: Offset(0, 2),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.white,
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
        ],
      ),
    );
  }
}
