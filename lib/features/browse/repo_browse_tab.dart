import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/extension_runtime.dart';
import '../../data/models.dart';
import '../../data/demo_state.dart';
import '../../data/repository_state.dart';
import '../../data/sources_state.dart';
import 'browse_screen.dart';
import 'source_detail_screen.dart';

const _langLabels = [
  ('ALL', 'Multi / Semua'),
  ('ID', 'Indonesia'),
  ('EN', 'English'),
  ('JP', '日本語 (Jepang)'),
  ('KR', '한국어 (Korea)'),
  ('CN', '中文 (China)'),
];

const _langGroupNames = {
  'ALL': 'Multi',
  'ID': 'Indonesia',
  'EN': 'English',
  'JP': 'Jepang',
  'KR': 'Korea',
  'CN': 'China',
};

final installedExtensionPackagesProvider =
    FutureProvider<Map<String, InstalledExtensionPackage>>((ref) async {
      final packages = await const ExtensionRuntimeBridge()
          .listInstalledExtensions();
      return {for (final package in packages) package.packageName: package};
    });

/// Sheet "Bahasa aktif" — toggle bahasa global, live tanpa tombol apply.
void showLanguageSheet(BuildContext context) {
  showAppSheet<void>(
    context,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final activeLangs = ref.watch(activeLangsProvider);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSheetTitle('Bahasa aktif', bottomGap: 4),
            Text(
              'Komik dari repository akan dikelompokkan berdasarkan bahasa '
              'yang aktif.',
              style: AppTypography.jakarta(
                size: 12.5,
                weight: FontWeight.w400,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            for (final (id, label) in _langLabels)
              InkWell(
                onTap: () => ref.read(activeLangsProvider.notifier).toggle(id),
                borderRadius: BorderRadius.circular(11),
                highlightColor: AppColors.rowHighlight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: AppTypography.jakarta(
                            size: 14,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      AppPillSwitch(
                        value: activeLangs.contains(id),
                        onChanged: (_) =>
                            ref.read(activeLangsProvider.notifier).toggle(id),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

/// Konten sub-tab Repository — spek 08.
class RepoBrowseTab extends ConsumerStatefulWidget {
  const RepoBrowseTab({super.key, required this.onOpenRepoList});

  final VoidCallback onOpenRepoList;

  @override
  ConsumerState<RepoBrowseTab> createState() => _RepoBrowseTabState();
}

class _RepoBrowseTabState extends ConsumerState<RepoBrowseTab> {
  String _search = '';
  final _searchController = TextEditingController();
  bool _refreshing = false;
  bool _autoRefreshScheduled = false;

  Future<void> _refreshRepositories({bool silent = false}) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final result = await ref.read(repositoriesProvider.notifier).refreshAll();
    ref.invalidate(installedExtensionPackagesProvider);
    if (!mounted) return;
    setState(() => _refreshing = false);
    if (silent) return;
    if (result.updated == 0) {
      AppToast.show(context, 'Repository belum bisa diperbarui');
    } else if (result.failed > 0) {
      AppToast.show(
        context,
        '${result.updated} repository diperbarui, ${result.failed} gagal',
      );
    } else {
      AppToast.show(context, 'Semua repository sudah terbaru');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final demoEmpty = ref.watch(demoRepoEmptyProvider);
    final repositories = demoEmpty
        ? const <ComicRepository>[]
        : ref.watch(repositoriesProvider);
    final activeLangs = ref.watch(activeLangsProvider);
    final installedPackages = ref.watch(installedExtensionPackagesProvider);
    final installedPackageNames = installedPackages.maybeWhen(
      data: (packages) => packages.keys.toSet(),
      orElse: () => const <String>{},
    );

    if (!_autoRefreshScheduled && repositories.isNotEmpty) {
      _autoRefreshScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshRepositories(silent: true);
      });
    }

    if (repositories.isEmpty) {
      return AppEmptyState(
        icon: const CustomPaint(
          size: Size.square(42),
          painter: RepoGlyphPainter(
            color: AppColors.emptyIcon,
            strokeWidth: 1.7,
          ),
        ),
        title: 'Belum ada repository',
        description: const TextSpan(
          text:
              'Repository berisi banyak sumber sekaligus dalam satu link, '
              'mirip daftar extension. Tambahkan satu untuk langsung dapat '
              'banyak pilihan sumber.',
        ),
        ctaLabel: 'Tambah Repository',
        onCta: widget.onOpenRepoList,
      );
    }

    if (activeLangs.isEmpty) {
      return _NoLangsPrompt(onPickLanguage: () => showLanguageSheet(context));
    }

    // Kelompokkan per bahasa aktif (urutan tetap ID, EN, JP, KR, CN).
    final orderedLangs = [
      for (final (id, _) in _langLabels)
        if (activeLangs.contains(id)) id,
    ];

    final query = _search.trim().toLowerCase();
    bool matchesQuery(ComicRepository repo, RepoSource source) {
      if (query.isEmpty) return true;
      return source.name.toLowerCase().contains(query) ||
          repo.name.toLowerCase().contains(query) ||
          (source.baseUrl ?? '').toLowerCase().contains(query) ||
          (source.pkg ?? '').toLowerCase().contains(query);
    }

    final installedRows = <_RepoSourceRowData>[];

    final rowsByLang = <String, List<_RepoSourceRowData>>{
      for (final lang in orderedLangs) lang: <_RepoSourceRowData>[],
    };
    for (final repo in repositories) {
      for (final rs in repo.sources) {
        if (!activeLangs.contains(rs.lang)) continue;
        if (!matchesQuery(repo, rs)) continue;
        final row = _RepoSourceRowData(repo: repo, source: rs);
        if (rs.pkg != null && installedPackageNames.contains(rs.pkg)) {
          installedRows.add(row);
        } else {
          rowsByLang[rs.lang]?.add(row);
        }
      }
    }
    final totalVisible =
        rowsByLang.values.fold<int>(0, (sum, rows) => sum + rows.length) +
        installedRows.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
          child: _RepoSearchField(
            controller: _searchController,
            onChanged: (value) => setState(() => _search = value),
            refreshing: _refreshing,
            onRefresh: _refreshRepositories,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
            children: [
              if (query.isNotEmpty && totalVisible == 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(30, 42, 30, 0),
                  child: Text(
                    'Sumber repository tidak ditemukan',
                    textAlign: TextAlign.center,
                    style: AppTypography.jakarta(
                      size: 14,
                      weight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              if (installedRows.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.packageCheck,
                        size: 13,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'TERPASANG · ${installedRows.length}',
                        style: AppTypography.jakarta(
                          size: 12,
                          weight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
                for (final row in installedRows) _RepoSourceRow(data: row),
                const SizedBox(height: 9),
              ],
              for (final lang in orderedLangs) ...[
                Builder(
                  builder: (context) {
                    final items =
                        rowsByLang[lang] ?? const <_RepoSourceRowData>[];
                    final label = _langGroupNames[lang] ?? lang;
                    if (query.isNotEmpty && items.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                          child: Text(
                            '${label.toUpperCase()} · ${items.length}',
                            style: AppTypography.jakarta(
                              size: 12,
                              weight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        if (items.isEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
                            child: Text(
                              'Belum ada sumber $label dari repository terpasang.',
                              style: AppTypography.jakarta(
                                size: 12.5,
                                weight: FontWeight.w400,
                                color: AppColors.textFaint,
                              ),
                            ),
                          )
                        else
                          for (final row in items) _RepoSourceRow(data: row),
                        const SizedBox(height: 9),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RepoSearchField extends StatelessWidget {
  const _RepoSearchField({
    required this.controller,
    required this.onChanged,
    required this.refreshing,
    required this.onRefresh,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(AppIcons.search, size: 18, color: AppColors.textFaint),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: AppColors.accent,
              style: AppTypography.jakarta(size: 14, weight: FontWeight.w400),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Cari sumber repository...',
                hintStyle: AppTypography.jakarta(
                  size: 14,
                  weight: FontWeight.w400,
                  color: AppColors.textFaint,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Perbarui repository',
            child: InkWell(
              onTap: refreshing ? null : onRefresh,
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 34,
                height: 34,
                child: refreshing
                    ? const Center(child: AppSpinner(size: 15, strokeWidth: 2))
                    : const Icon(
                        AppIcons.refresh,
                        size: 17,
                        color: AppColors.textMuted,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoLangsPrompt extends StatelessWidget {
  const _NoLangsPrompt({required this.onPickLanguage});

  final VoidCallback onPickLanguage;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 0, 30, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surfaceEmptyIcon,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: const Icon(
                LucideIcons.globe,
                size: 32,
                color: AppColors.emptyIcon,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Aktifkan bahasa dulu',
              style: AppTypography.jakarta(size: 15, weight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 250),
              child: Text(
                'Pilih bahasa yang ingin ditampilkan, komik dari repository '
                'akan dikelompokkan otomatis per bahasa.',
                textAlign: TextAlign.center,
                style: AppTypography.jakarta(
                  size: 13,
                  weight: FontWeight.w400,
                  height: 1.5,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: onPickLanguage,
              borderRadius: BorderRadius.circular(13),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  'Pilih Bahasa',
                  style: AppTypography.jakarta(
                    size: 13.5,
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
}

class _RepoSourceRowData {
  const _RepoSourceRowData({required this.repo, required this.source});

  final ComicRepository repo;
  final RepoSource source;

  String get savedId => 'rp-${repo.id}-${source.id}';

  /// Sumber sintetis untuk dibuka di Source Detail (read-only, tidak
  /// menambah ke Sumber Saya).
  ComicSource toSyntheticSource() => ComicSource(
    id: savedId,
    name: source.name,
    url: (source.baseUrl ?? repo.url).replaceFirst(RegExp(r'^https?://'), ''),
    lang: source.lang,
    hue: source.hue,
    parserKind: source.pkg == null
        ? source.parserKind
        : 'extension-runtime:${source.pkg}',
    repoPackage: source.pkg,
    repoSourceId: source.id,
  );
}

class _RepoSourceRow extends ConsumerWidget {
  const _RepoSourceRow({required this.data});

  final _RepoSourceRowData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installedPackages = ref.watch(installedExtensionPackagesProvider);
    final packageName = data.source.pkg;
    final installedPackage = packageName == null
        ? null
        : installedPackages.maybeWhen(
            data: (packages) => packages[packageName],
            orElse: () => null,
          );
    final installed = installedPackage != null;
    final updateAvailable =
        installedPackage != null &&
        repositoryUpdateAvailable(
          source: data.source,
          installedVersionCode: installedPackage.versionCode,
          installedVersionName: installedPackage.versionName,
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SourceDetailScreen(
                sourceId: data.savedId,
                fallbackSource: data.toSyntheticSource(),
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              SourceSiteIcon(
                websiteUrl: data.source.baseUrl ?? data.repo.url,
                initial: data.source.initial,
                hue: data.source.hue,
                size: 38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.source.name,
                      style: AppTypography.jakarta(
                        size: 13.5,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.repo.name,
                      style: AppTypography.jakarta(
                        size: 11,
                        weight: FontWeight.w400,
                        color: AppColors.textFaintestAlt,
                      ),
                    ),
                    if (updateAvailable) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Pembaruan ${data.source.version ?? ''} tersedia'
                            .trim(),
                        style: AppTypography.jakarta(
                          size: 10.5,
                          weight: FontWeight.w700,
                          color: AppColors.warningAlt,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (packageName != null) ...[
                const SizedBox(width: 8),
                _ExtensionInstallButton(
                  data: data,
                  installed: installed,
                  updateAvailable: updateAvailable,
                  loading: installedPackages.isLoading,
                ),
              ],
              const Icon(
                AppIcons.forward,
                size: 16,
                color: AppColors.textFaintest,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExtensionInstallButton extends ConsumerStatefulWidget {
  const _ExtensionInstallButton({
    required this.data,
    required this.installed,
    required this.updateAvailable,
    required this.loading,
  });

  final _RepoSourceRowData data;
  final bool installed;
  final bool updateAvailable;
  final bool loading;

  @override
  ConsumerState<_ExtensionInstallButton> createState() =>
      _ExtensionInstallButtonState();
}

class _ExtensionInstallButtonState
    extends ConsumerState<_ExtensionInstallButton>
    with WidgetsBindingObserver {
  bool _busy = false;
  bool _refreshOnResume = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_refreshOnResume) return;
    _refreshOnResume = false;
    ref.invalidate(installedExtensionPackagesProvider);
  }

  Future<void> _install() async {
    if (_busy || (widget.installed && !widget.updateAvailable)) return;
    final apkUrl = repositoryApkUrl(
      widget.data.repo.url,
      widget.data.source.apk,
    );
    final apk = widget.data.source.apk;
    if (apkUrl == null || apk == null) {
      AppToast.show(context, 'Link APK extension tidak ditemukan');
      return;
    }
    setState(() => _busy = true);
    try {
      await const ExtensionRuntimeBridge().installExtensionApk(
        apkUrl: apkUrl,
        fileName: apk,
      );
      if (!mounted) return;
      _refreshOnResume = true;
      ref.invalidate(installedExtensionPackagesProvider);
      AppToast.show(
        context,
        widget.updateAvailable
            ? 'Installer pembaruan extension dibuka'
            : 'Installer extension dibuka',
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, 'Gagal membuka installer: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showInstalledOptions() async {
    if (_busy) return;
    final packageName = widget.data.source.pkg;
    if (packageName == null) return;
    await showAppSheet<void>(
      context,
      menuStyle: true,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ContextMenuPreview(
            cover: comicCover(widget.data.source.hue),
            title: widget.data.source.name,
            subtitle: packageName,
          ),
          AppSheetMenuRow(
            icon: LucideIcons.packageCheck,
            iconColor: AppColors.success,
            label: 'Extension sudah terpasang',
            onTap: () => Navigator.pop(sheetContext),
          ),
          if (widget.updateAvailable)
            AppSheetMenuRow(
              icon: AppIcons.refresh,
              iconColor: AppColors.warningAlt,
              label: widget.data.source.version == null
                  ? 'Perbarui extension'
                  : 'Perbarui ke ${widget.data.source.version}',
              onTap: () {
                Navigator.pop(sheetContext);
                _install();
              },
            ),
          AppSheetMenuRow(
            icon: AppIcons.delete,
            label: 'Hapus instal extension',
            destructive: true,
            onTap: () {
              Navigator.pop(sheetContext);
              _uninstall(packageName);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _uninstall(String packageName) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await const ExtensionRuntimeBridge().uninstallExtensionPackage(
        packageName,
      );
      if (!mounted) return;
      _refreshOnResume = true;
      AppToast.show(context, 'Dialog hapus instal dibuka');
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, 'Gagal membuka hapus instal: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.updateAvailable
        ? AppColors.warningAlt
        : widget.installed
        ? AppColors.success
        : AppColors.accentText;
    return Tooltip(
      message: widget.updateAvailable
          ? 'Perbarui extension'
          : widget.installed
          ? 'Kelola extension'
          : 'Instal extension',
      child: InkWell(
        onTap: widget.loading || _busy
            ? null
            : widget.updateAvailable
            ? _install
            : widget.installed
            ? _showInstalledOptions
            : _install,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: widget.updateAvailable
                ? AppColors.warning.withValues(alpha: 0.12)
                : widget.installed
                ? AppColors.success.withValues(alpha: 0.12)
                : const Color(0x241E88C8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.updateAvailable
                  ? AppColors.warningAlt.withValues(alpha: 0.65)
                  : widget.installed
                  ? AppColors.success.withValues(alpha: 0.5)
                  : const Color(0x661E88C8),
            ),
          ),
          child: _busy || widget.loading
              ? Center(
                  child: AppSpinner(size: 14, strokeWidth: 2, color: color),
                )
              : Icon(
                  widget.updateAvailable
                      ? AppIcons.refresh
                      : widget.installed
                      ? Icons.verified_rounded
                      : LucideIcons.download,
                  size: 16,
                  color: color,
                ),
        ),
      ),
    );
  }
}
