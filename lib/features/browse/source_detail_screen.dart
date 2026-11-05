import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/extension_runtime.dart';
import '../../data/extension_update_helper.dart';
import '../../data/library_state.dart';
import '../../data/models.dart';
import '../../data/repository_state.dart';
import '../../data/source_url.dart';
import '../../data/sources_state.dart';
import '../../data/vpn_state.dart';
import '../../sources/manga_source.dart';
import '../../sources/source_catalog.dart';
import '../detail/comic_detail_screen.dart';
import 'add_source_screen.dart';
import 'repo_browse_tab.dart';
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
  String? _discoverWebViewUrl;
  List<Comic> _discoverResults = const [];
  Timer? _searchDebounce;

  // Paginasi grid discover — sebelumnya cuma pernah fetch halaman 1 dan
  // tidak pernah nambah lagi biar pun di-refresh, jadi kelihatan "isinya
  // segitu-segitu aja" walau sumbernya sebenarnya punya ratusan judul.
  int _discoverPage = 1;
  bool _hasNextPage = true;
  bool _loadingMore = false;
  int _discoverRequestId = 0;
  final _gridScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _gridScrollController.addListener(_onGridScroll);
    _initMatchedSource();
    final source = _source;
    if (source != null) {
      if (_matchedSource != null) _loadDiscover(source);
      _checkDomainHealth(source);
    }
  }

  void _initMatchedSource() {
    final source = _source;
    if (source == null) return;
    _matchedSource =
        SourceCatalog.matchByUrl(
          source.url,
          fallbackBaseUrls: source.urlAliases,
        ) ??
        SourceCatalog.matchByName(
          source.name,
          source.url,
        ) ??
        (source.parserKind != null &&
                !source.parserKind!.startsWith('extension-runtime:')
            ? SourceCatalog.buildGeneric(
                source.parserKind!,
                source.name,
                source.url.startsWith('http')
                    ? source.url
                    : 'https://${source.url}',
                fallbackBaseUrls: source.urlAliases,
              )
            : null) ??
        _repoMatchedSource(source) ??
        SourceCatalog.buildAutomatic(
          source.name,
          source.url.startsWith('http')
              ? source.url
              : 'https://${source.url}',
          preferredKind: source.parserKind,
          lang: source.lang,
          fallbackBaseUrls: source.urlAliases,
        );
  }

  Future<void> _checkDomainHealth(ComicSource source) async {
    try {
      final probe = await const ExtensionRuntimeBridge().probeUrl(source.url);
      final finalUrl = probe.finalUrl;
      if (finalUrl.isNotEmpty) {
        final newUri = Uri.tryParse(finalUrl);
        final oldUri = Uri.tryParse(
          source.url.startsWith('http') ? source.url : 'https://${source.url}',
        );
        final oldHost = oldUri?.host.toLowerCase() ?? '';
        final newHost = newUri?.host.toLowerCase() ?? '';
        if (oldHost.isNotEmpty &&
            newHost.isNotEmpty &&
            oldHost != newHost &&
            !newHost.contains('turnstile') &&
            !newHost.contains('challenges.cloudflare') &&
            !newHost.contains('internetpositif')) {
          final newBaseUrl = '${newUri!.scheme}://${newUri.host}';
          final updated = await ref
              .read(sourcesProvider.notifier)
              .updateSourceUrl(source.id, newBaseUrl);
          if (updated && mounted) {
            AppToast.show(
              context,
              '🌐 Domain ${source.name} dialihkan ke ${newUri.host}. Alamat sumber otomatis disesuaikan.',
            );
            _initMatchedSource();
            final updatedSource = _source;
            if (updatedSource != null) {
              _loadDiscover(updatedSource);
            }
          }
        }
      }
    } catch (_) {}
  }

  MangaSource? _repoMatchedSource(ComicSource source) {
    final baseUrl = source.url.startsWith('http')
        ? source.url
        : 'https://${source.url}';
    final match = findRepoSource(
      repositories: ref.read(repositoriesProvider),
      rawUrl: baseUrl,
      packageName: source.repoPackage,
      sourceId: source.repoSourceId,
      name: source.name,
      nameAliases: source.nameAliases,
      urlAliases: source.urlAliases,
    );
    final packageName = match?.source.pkg;
    if (packageName == null) return null;
    final currentBaseUrl = match?.source.baseUrl ?? baseUrl;
    final fallbackBaseUrls = <String>{
      ...source.urlAliases,
      if (currentBaseUrl != baseUrl) baseUrl,
      ...?match?.source.baseUrlAliases,
    };
    return SourceCatalog.buildAutomatic(
      source.name,
      currentBaseUrl,
      preferredKind: 'extension-runtime:$packageName',
      lang: match?.source.lang,
      fallbackBaseUrls: fallbackBaseUrls,
    );
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
    final requestId = ++_discoverRequestId;
    try {
      final result = switch (_tab) {
        _DiscoverTab.popular => await matched.fetchPopular(nextPage),
        _DiscoverTab.latest => await matched.fetchLatest(nextPage),
        _DiscoverTab.search => await matched.fetchSearch(
          _search.trim(),
          nextPage,
        ),
      };
      if (!mounted || requestId != _discoverRequestId) return;
      final incoming = result.mangas.map((m) => _toComic(source, m));
      final merged = mergeDiscoverResults(_discoverResults, incoming);
      final addedCount = merged.length - _discoverResults.length;
      setState(() {
        _discoverResults = merged;
        _discoverPage = nextPage;
        // Beberapa situs mengembalikan halaman sebelumnya lagi tetapi tetap
        // bilang masih ada next page. Berhenti kalau tidak ada URL baru agar
        // listener dasar grid tidak request tanpa akhir dan mengusik offset.
        _hasNextPage = result.hasNextPage && addedCount > 0;
        _loadingMore = false;
      });
    } catch (_) {
      // Diam-diam gagal — yang sudah kemuat tetap ditampilkan, biarkan
      // scroll ke bawah lagi jadi pemicu buat coba lagi.
      if (!mounted || requestId != _discoverRequestId) return;
      setState(() => _loadingMore = false);
    }
  }

  ComicSource? get _source {
    final sources = ref.read(sourcesProvider);
    for (final s in sources) {
      if (s.id == widget.sourceId) return s;
    }
    return widget.fallbackSource;
  }

  Comic _toComic(ComicSource source, SourceManga manga) {
    final activeUrl = _matchedSource == null
        ? manga.url
        : rebaseSourceUrl(manga.url, _matchedSource!.baseUrl);
    return Comic(
      id: 'src_${source.id}_${Uri.encodeComponent(activeUrl)}',
      title: manga.title,
      src: source.name,
      hue: source.hue,
      ch: 0,
      coverUrl: manga.thumbnailUrl,
      coverHeaders: manga.headers,
      sourceMangaUrl: activeUrl,
    );
  }

  /// Ambil daftar komik ASLI dari sumber yang punya parser native (lihat
  /// lib/sources/) sesuai tab aktif. Sumber di luar daftar tetap pakai
  /// daftar demo statis (lihat [_discoverItems]) — tidak berubah.
  Future<void> _loadDiscover(ComicSource source, {int page = 1}) async {
    final matched = _matchedSource;
    if (matched == null) return;
    final requestId = ++_discoverRequestId;
    if (_tab == _DiscoverTab.search && _search.trim().isEmpty) {
      setState(() {
        _discoverResults = const [];
        _discoverLoading = false;
        _discoverError = null;
        _discoverWebViewUrl = null;
        _hasNextPage = false;
        _loadingMore = false;
      });
      return;
    }
    setState(() {
      _discoverLoading = true;
      _loadingMore = false;
      _discoverError = null;
      _discoverWebViewUrl = null;
    });
    try {
      final result = switch (_tab) {
        _DiscoverTab.popular => await matched.fetchPopular(page),
        _DiscoverTab.latest => await matched.fetchLatest(page),
        _DiscoverTab.search => await matched.fetchSearch(_search.trim(), page),
      };
      if (!mounted || requestId != _discoverRequestId) return;
      setState(() {
        _discoverResults = result.mangas
            .map((m) => _toComic(source, m))
            .toList();
        _discoverPage = page;
        _hasNextPage = result.hasNextPage;
        _discoverLoading = false;
      });
    } catch (e) {
      if (!mounted || requestId != _discoverRequestId) return;
      setState(() {
        _discoverError = '$e';
        _discoverLoading = false;
        _discoverWebViewUrl = e is MangaSourceWebViewException
            ? e.url
            : source.url;
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
    if (_gridScrollController.hasClients) {
      _gridScrollController.jumpTo(0);
    }
    final source = _source;
    if (_matchedSource != null && source != null) _loadDiscover(source);
  }

  /// Refresh daftar komik. Sumber dengan parser native: fetch ulang
  /// sungguhan. Sumber lain: simulasi prototipe ~1.1s.
  Future<void> _refresh({bool fromVpn = false}) async {
    if (_refreshing) return;
    final source = _source;
    if (_matchedSource != null && source != null) {
      setState(() => _refreshing = true);
      await _loadDiscover(source);
      if (!mounted) return;
      setState(() => _refreshing = false);
      AppToast.show(
        context,
        fromVpn
            ? '🛡️ VPN telah diaktifkan · Daftar komik berhasil diperbarui'
            : 'Daftar komik diperbarui',
      );
      return;
    }
    setState(() => _refreshing = true);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    setState(() => _refreshing = false);
    AppToast.show(
      context,
      fromVpn
          ? '🛡️ VPN telah diaktifkan · Daftar komik berhasil diperbarui'
          : 'Daftar komik diperbarui',
    );
  }

  /// Ulangi request parser aktif. WebView tetap jadi fallback bila seluruh
  /// strategi parser masih gagal.
  Future<void> _retry({bool fromVpn = false}) async {
    if (_retrying) return;
    final source = _source;
    if (source == null) return;
    setState(() => _retrying = true);
    if (_matchedSource != null) {
      await _loadDiscover(source);
    }
    if (!mounted) return;
    setState(() => _retrying = false);
    if (fromVpn) {
      AppToast.show(
        context,
        _discoverError == null
            ? '🛡️ VPN telah diaktifkan · Komik berhasil diperbarui'
            : '🛡️ VPN telah diaktifkan · Web masih diblokir (coba WebView)',
      );
    } else {
      AppToast.show(
        context,
        _discoverError == null
            ? 'Sumber berhasil dimuat ulang'
            : 'Masih belum bisa dibaca otomatis — coba WebView',
      );
    }
  }

  void _openWebView(ComicSource source, {String? initialUrl}) {
    Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => WebViewScreen(
          sourceId: source.id,
          fallbackSource: widget.fallbackSource,
          initialUrl: initialUrl,
        ),
      ),
    ).then((_) {
      if (mounted) {
        _initMatchedSource();
        _retry();
      }
    });
  }

  void _resetSession(ComicSource source) {
    ref.read(sourcesProvider.notifier).setSession(source.id, false);
    AppToast.show(context, 'Session di-reset untuk ${source.name}');
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild kalau sumber diedit/dihapus, sementara callback dan debounce
    // membaca snapshot lewat `_source` tanpa membuat listener di luar build.
    ref.watch(sourcesProvider);
    final source = _source;
    if (source == null) {
      // Sumber dihapus saat layar terbuka — kembali.
      return const Scaffold(backgroundColor: AppColors.bg, body: SizedBox());
    }

    final repoMatch = findRepoSource(
      repositories: ref.watch(repositoriesProvider),
      rawUrl: source.url,
      packageName: source.repoPackage,
      sourceId: source.repoSourceId,
      name: source.name,
      nameAliases: source.nameAliases,
      urlAliases: source.urlAliases,
    );
    final installedPackages = ref.watch(installedExtensionPackagesProvider);
    final installedMap = installedPackages.maybeWhen(
      data: (pkgs) => pkgs,
      orElse: () => const <String, InstalledExtensionPackage>{},
    );
    final installedPkg = repoMatch?.source.pkg != null
        ? installedMap[repoMatch!.source.pkg]
        : null;
    final isInstalled = installedPkg != null;
    final updateAvailable = isInstalled &&
        repoMatch != null &&
        repositoryUpdateAvailable(
          source: repoMatch.source,
          installedVersionCode: installedPkg.versionCode,
          installedVersionName: installedPkg.versionName,
        );

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
                  const SizedBox(width: 8),
                  KizenVpnQuickButton(
                    compact: true,
                    onToggled: (enabled) {
                      if (enabled) _refresh(fromVpn: true);
                    },
                  ),
                  const SizedBox(width: 8),
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
            if (updateAvailable)
              _buildRepoUpdateBanner(
                repoMatch: repoMatch,
                installedPkg: installedPkg,
              ),
            Expanded(
              child: _canUseAutomaticReader(source)
                  ? _buildParsable(source)
                  : _buildErrorState(source),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepoUpdateBanner({
    required RepoSourceMatch repoMatch,
    required InstalledExtensionPackage installedPkg,
  }) {
    final apkUrl = repositoryApkUrl(
      repoMatch.repository.url,
      repoMatch.source.apk,
    );
    final apk = repoMatch.source.apk;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.warningAlt.withValues(alpha: 0.55),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.warningAlt.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.warningAlt.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              LucideIcons.packagePlus,
              size: 19,
              color: AppColors.warningAlt,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Pembaruan Ekstensi',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.jakarta(
                          size: 13,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warningAlt.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'v${repoMatch.source.version ?? 'terbaru'}',
                        style: AppTypography.mono(
                          size: 10,
                          weight: FontWeight.w700,
                          color: AppColors.warningAlt,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Tersedia di ${repoMatch.repository.name}. Perbarui agar web lancar.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.jakarta(
                    size: 11,
                    weight: FontWeight.w400,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: apkUrl == null || apk == null
                ? null
                : () {
                    ExtensionUpdateHelper.showUpdateSheet(
                      context,
                      ref: ref,
                      name: repoMatch.source.name,
                      packageName: repoMatch.source.pkg!,
                      apkUrl: apkUrl,
                      fileName: apk,
                      newVersion: repoMatch.source.version,
                      hue: repoMatch.source.hue,
                      onInstalled: () {
                        _initMatchedSource();
                        final s = _source;
                        if (s != null) _loadDiscover(s);
                      },
                    );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warningAlt,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
              elevation: 0,
            ),
            child: Text(
              'Perbarui',
              style: AppTypography.jakarta(
                size: 12,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- State A: parsable ---

  bool _canUseAutomaticReader(ComicSource source) {
    if (!source.active) return false;
    return _matchedSource != null;
  }

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
          child: _matchedSource != null && _discoverLoading && items.isEmpty
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
                    if (_discoverLoading && items.isNotEmpty)
                      const Positioned(
                        top: 10,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          child: Center(
                            child: AppSpinner(size: 22, strokeWidth: 2.5),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  bool _installingExtension = false;

  Future<void> _installExtensionFromRepo(RepoSourceMatch match) async {
    final apkUrl = repositoryApkUrl(
      match.repository.url,
      match.source.apk,
    );
    final apk = match.source.apk;
    final pkg = match.source.pkg;
    if (apkUrl == null || apk == null || pkg == null) {
      AppToast.show(context, 'Link APK extension tidak ditemukan');
      return;
    }
    setState(() => _installingExtension = true);
    try {
      final installedPackages = ref.read(installedExtensionPackagesProvider);
      final isInstalled = installedPackages.maybeWhen(
        data: (pkgs) => pkgs.containsKey(pkg),
        orElse: () => false,
      );
      if (isInstalled) {
        await ExtensionUpdateHelper.showUpdateSheet(
          context,
          ref: ref,
          name: match.source.name,
          packageName: pkg,
          apkUrl: apkUrl,
          fileName: apk,
          newVersion: match.source.version,
          hue: match.source.hue,
          onInstalled: () {
            _initMatchedSource();
            final s = _source;
            if (s != null) _loadDiscover(s);
          },
        );
      } else {
        await ExtensionUpdateHelper.installDirect(
          context,
          ref: ref,
          apkUrl: apkUrl,
          fileName: apk,
          onInstalled: () {
            _initMatchedSource();
            final s = _source;
            if (s != null) _loadDiscover(s);
          },
        );
      }
    } finally {
      if (mounted) setState(() => _installingExtension = false);
    }
  }

  Widget _buildDiscoverError(ComicSource source) {
    RepoSourceMatch? repoMatch;
    if (source.repoPackage != null) {
      repoMatch = findRepoSource(
        repositories: ref.read(repositoriesProvider),
        rawUrl: source.url,
        packageName: source.repoPackage,
        sourceId: source.repoSourceId,
      );
    }
    final installedPackages = ref.watch(installedExtensionPackagesProvider);
    final isInstalled = source.repoPackage != null &&
        installedPackages.maybeWhen(
          data: (pkgs) => pkgs.containsKey(source.repoPackage),
          orElse: () => false,
        );

    final isMissingExtension =
        source.repoPackage != null && !isInstalled && repoMatch != null;

    final isCloudflareChallenge =
        _discoverError?.contains('Cloudflare') == true ||
        _discoverError?.contains('Turnstile') == true ||
        _discoverError?.contains('403') == true;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        children: [
          if (isCloudflareChallenge) ...[
            Container(
              padding: const EdgeInsets.all(18),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    ),
                    child: const Icon(
                      LucideIcons.shieldAlert,
                      color: Color(0xFF10B981),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Verifikasi Keamanan (Cloudflare)',
                    textAlign: TextAlign.center,
                    style: AppTypography.jakarta(
                      size: 15,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Situs ${source.name} mengaktifkan proteksi Cloudflare Turnstile. Cukup buka browser internal sekali saja untuk verifikasi, setelah itu seluruh komik langsung terbuka otomatis.',
                    textAlign: TextAlign.center,
                    style: AppTypography.jakarta(
                      size: 12,
                      weight: FontWeight.w400,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: FilledButton.icon(
                      onPressed: () => _openWebView(
                        source,
                        initialUrl: _discoverWebViewUrl ?? source.url,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(LucideIcons.shieldCheck, size: 16),
                      label: Text(
                        'Selesaikan Verifikasi di Browser',
                        style: AppTypography.jakarta(
                          size: 13,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => _loadDiscover(source),
                    icon: const Icon(LucideIcons.refreshCw, size: 14),
                    label: const Text('Coba Muat Ulang'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isMissingExtension) ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    LucideIcons.packagePlus,
                    color: AppColors.accent,
                    size: 34,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Ekstensi ${source.name} Belum Terpasang',
                    style: AppTypography.jakarta(
                      size: 14.5,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sumber ini memerlukan ekstensi resmi Keiyoushi agar komik dan chapter dapat dimuat secara lancar (seperti di Tachiyomi/Mihon).',
                    textAlign: TextAlign.center,
                    style: AppTypography.jakarta(
                      size: 12,
                      weight: FontWeight.w400,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: FilledButton.icon(
                      onPressed: _installingExtension
                          ? null
                          : () => _installExtensionFromRepo(repoMatch!),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: _installingExtension
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(LucideIcons.download, size: 16),
                      label: Text(
                        _installingExtension
                            ? 'Membuka Installer...'
                            : 'Pasang Ekstensi Sekarang',
                        style: AppTypography.jakarta(
                          size: 13,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!isCloudflareChallenge) ...[
            Text(
              isMissingExtension
                  ? 'Atau gunakan metode browser di bawah jika belum ingin memasang ekstensi:'
                  : 'Gagal memuat daftar komik.\n${_discoverError ?? ''}',
              textAlign: TextAlign.center,
              style: AppTypography.jakarta(
                size: 12.5,
                weight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => _openWebView(
                    source,
                    initialUrl: _discoverWebViewUrl ?? source.url,
                  ),
                  borderRadius: BorderRadius.circular(11),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.4),
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
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
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
    final isCloudflare = _discoverError != null &&
        (_discoverError!.toLowerCase().contains('403') ||
            _discoverError!.toLowerCase().contains('cloudflare') ||
            _discoverError!.toLowerCase().contains('turnstile') ||
            _discoverError!.toLowerCase().contains('clearance') ||
            _discoverError!.toLowerCase().contains('just a moment'));

    final message = isCloudflare
        ? 'Website meminta verifikasi keamanan Cloudflare. Buka WebView untuk menyelesaikan verifikasi, sesi akan tersimpan otomatis.'
        : switch (source.status) {
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
                if (!ref.watch(vpnProvider).isEnabled) ...[
                  _primaryAction(
                    label: 'Nyalakan VPN & Muat Ulang',
                    icon: LucideIcons.shieldCheck,
                    color: const Color(0xFF10B981),
                    onTap: () async {
                      await ref.read(vpnProvider.notifier).toggle();
                      if (mounted) {
                        AppToast.show(
                          context,
                          '🛡️ VPN telah diaktifkan · Memuat ulang komik...',
                        );
                        _retry(fromVpn: true);
                      }
                    },
                  ),
                  const SizedBox(height: 9),
                ],
                _primaryAction(
                  label: isCloudflare
                      ? 'Verifikasi Cloudflare di WebView'
                      : 'Buka lewat WebView',
                  icon: isCloudflare ? LucideIcons.shieldCheck : LucideIcons.globe,
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
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: color ?? AppColors.accent,
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

/// Gabungkan pagination berdasarkan ID yang dibentuk dari URL sumber.
/// Urutan item lama tidak disentuh supaya anchor scroll Flutter tetap stabil.
@visibleForTesting
List<Comic> mergeDiscoverResults(
  List<Comic> current,
  Iterable<Comic> incoming,
) {
  final seen = <String>{};
  return [
    for (final comic in [...current, ...incoming])
      if (seen.add(comic.id)) comic,
  ];
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
                      headers: comic.coverHeaders,
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
