import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/extension_runtime.dart';
import '../../data/repository_state.dart';
import '../../data/sources_state.dart';
import '../../sources/source_catalog.dart';

enum _TestState { idle, loading, ok, error }

/// Add Source URL — spek 09.
class AddSourceScreen extends ConsumerStatefulWidget {
  const AddSourceScreen({super.key, this.initialSource});

  final ComicSource? initialSource;

  @override
  ConsumerState<AddSourceScreen> createState() => _AddSourceScreenState();
}

class _AddSourceScreenState extends ConsumerState<AddSourceScreen> {
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _descController = TextEditingController();
  String _lang = 'ID';
  _TestState _testState = _TestState.idle;

  /// Kind parser tema generik yang berhasil dideteksi cocok (kalau URL-nya
  /// bukan salah satu dari 4 sumber native) — lihat [_testSource] &
  /// `SourceCatalog.detectGeneric`.
  String? _detectedParserKind;
  RepoSourceMatch? _repoMatch;
  InstalledExtensionSourceMatch? _installedExtensionMatch;

  bool get _isEdit => widget.initialSource != null;

  @override
  void initState() {
    super.initState();
    final source = widget.initialSource;
    if (source != null) {
      _nameController.text = source.name;
      _urlController.text = source.url;
      _lang = source.lang.isEmpty ? 'ID' : source.lang;
      _detectedParserKind = source.parserKind;
      _repoMatch = findRepoSource(
        repositories: ref.read(repositoriesProvider),
        rawUrl: source.url,
        packageName: source.repoPackage,
        sourceId: source.repoSourceId,
      );
      _testState = source.status == SourceStatus.normal
          ? _TestState.ok
          : _TestState.idle;
    }
    _nameController.addListener(_onFormChanged);
    _urlController.addListener(_onFormChanged);
  }

  void _onFormChanged() => setState(() {});

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _descController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      _urlController.text.trim().isNotEmpty;

  /// Uji reachability URL. Kalau URL cocok salah satu sumber yang punya
  /// parser native (lihat lib/sources/), benar-benar coba ambil daftar
  /// komik populer. Kalau bukan, coba beberapa parser TEMA GENERIK
  /// (`SourceCatalog.detectGeneric`) — banyak situs komik Indonesia pakai
  /// tema WordPress yang sama (mis. MangaThemesia), jadi lumayan sering
  /// bisa langsung kebaca otomatis walau situsnya bukan salah satu dari 4
  /// yang secara eksplisit didukung. Gagal semua → tetap bisa disimpan
  /// sebagai sumber manual (Web View).
  Future<void> _testSource() async {
    if (_testState == _TestState.loading) return;
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _testState = _TestState.loading;
      _detectedParserKind = null;
      _repoMatch = null;
      _installedExtensionMatch = null;
    });

    final repoMatch = findRepoSource(
      repositories: ref.read(repositoriesProvider),
      rawUrl: url,
    );
    if (repoMatch?.source.pkg != null) {
      final repoBaseUrl = repoMatch!.source.baseUrl ?? url;
      final packageName = repoMatch.source.pkg!;
      final readable = await SourceCatalog.probeGeneric(
        'extension-runtime:$packageName',
        repoMatch.source.name,
        repoBaseUrl,
        lang: repoMatch.source.lang,
      );
      if (!mounted) return;
      setState(() {
        _repoMatch = repoMatch;
        _detectedParserKind = 'extension-runtime:$packageName';
        _testState = readable ? _TestState.ok : _TestState.error;
      });
      return;
    }

    final builtIn = SourceCatalog.matchByUrl(url);
    if (builtIn != null) {
      try {
        await builtIn.fetchPopular(1);
        if (!mounted) return;
        setState(() => _testState = _TestState.ok);
      } catch (_) {
        if (!mounted) return;
        setState(() => _testState = _TestState.error);
      }
      return;
    }

    try {
      final installedMatch = await findInstalledExtensionForUrl(url);
      if (installedMatch != null) {
        final extensionSource = SourceCatalog.buildGeneric(
          'extension-runtime:${installedMatch.package.packageName}',
          installedMatch.source.name,
          installedMatch.source.baseUrl,
          lang: installedMatch.source.lang,
        );
        final page = await extensionSource?.fetchPopular(1);
        if (page != null && page.mangas.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _installedExtensionMatch = installedMatch;
            _detectedParserKind =
                'extension-runtime:${installedMatch.package.packageName}';
            _testState = _TestState.ok;
          });
          return;
        }
      }
    } catch (_) {
      // Lanjut ke parser tema jika APK terpasang tetapi source sedang gagal.
    }

    final name = _nameController.text.trim().isEmpty
        ? url
        : _nameController.text.trim();
    final normalizedUrl = url.startsWith('http') ? url : 'https://$url';
    final kind = await SourceCatalog.detectGeneric(name, normalizedUrl);
    if (!mounted) return;
    setState(() {
      _testState = kind != null ? _TestState.ok : _TestState.error;
      _detectedParserKind = kind;
    });
  }

  Future<void> _saveSource() async {
    if (!_canSave) return;
    final rawUrl = _urlController.text.trim();
    final cleanUrl = rawUrl
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceFirst(RegExp(r'/$'), '');
    final sources = ref.read(sourcesProvider);
    if (sources.any(
      (s) => s.url == cleanUrl && s.id != widget.initialSource?.id,
    )) {
      AppToast.show(context, 'Sumber sudah ada');
      return;
    }
    // parserKind cuma relevan buat sumber custom (di luar 4 sumber
    // native) — kalau URL-nya cocok salah satu dari itu, resolusinya
    // sudah lewat SourceCatalog.matchByUrl (by URL), tidak perlu ditandai.
    final isBuiltIn = SourceCatalog.matchByUrl(rawUrl) != null;
    final initial = widget.initialSource;
    final sameUrl = initial?.url == cleanUrl;
    final repoMatch = findRepoSource(
      repositories: ref.read(repositoriesProvider),
      rawUrl: rawUrl,
      packageName: sameUrl ? initial?.repoPackage : null,
      sourceId: sameUrl ? initial?.repoSourceId : null,
    );
    var installedMatch = _installedExtensionMatch;
    if (repoMatch?.source.pkg == null &&
        installedMatch == null &&
        !isBuiltIn &&
        _detectedParserKind == null) {
      installedMatch = await findInstalledExtensionForUrl(rawUrl);
      if (!mounted) return;
    }
    final extensionPackage =
        repoMatch?.source.pkg ??
        installedMatch?.package.packageName ??
        (sameUrl ? initial?.repoPackage : null);
    final extensionSourceId =
        repoMatch?.source.id ??
        installedMatch?.source.id.toString() ??
        (sameUrl ? initial?.repoSourceId : null);
    var parserKind = extensionPackage == null
        ? (isBuiltIn ? null : _detectedParserKind)
        : 'extension-runtime:$extensionPackage';
    var status =
        extensionPackage != null || isBuiltIn || _testState == _TestState.ok
        ? SourceStatus.normal
        : SourceStatus.webview;
    if (_testState == _TestState.error) status = SourceStatus.webview;
    if (!isBuiltIn && parserKind == null) {
      final normalizedUrl = rawUrl.startsWith('http')
          ? rawUrl
          : 'https://$rawUrl';
      final name = _nameController.text.trim().isEmpty
          ? cleanUrl
          : _nameController.text.trim();
      parserKind = await SourceCatalog.detectGeneric(name, normalizedUrl);
      if (!mounted) return;
      if (parserKind != null) status = SourceStatus.normal;
    }
    final source = ComicSource(
      id: initial?.id ?? 's${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      url: cleanUrl,
      lang: _lang,
      hue: initial?.hue ?? 200 + math.Random().nextInt(140),
      active: initial?.active ?? true,
      session: initial?.session ?? false,
      status: status,
      parserKind: parserKind,
      repoPackage: extensionPackage,
      repoSourceId: extensionSourceId,
    );
    final notifier = ref.read(sourcesProvider.notifier);
    if (_isEdit) {
      await notifier.update(source);
    } else {
      await notifier.add(source);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    AppToast.show(
      context,
      _isEdit
          ? 'Sumber diperbarui'
          : parserKind != null
          ? 'Sumber ditambahkan · struktur situsnya terdeteksi bisa dibaca otomatis'
          : 'Sumber ditambahkan',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Row(
                children: [
                  AppBackButton(onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 8),
                  Text(
                    _isEdit ? 'Edit Sumber' : 'Tambah Sumber',
                    style: AppTypography.jakarta(
                      size: 19,
                      weight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Text(
                    'Masukkan URL website komik. Setelah disimpan, sumber ini '
                    'bisa dipakai untuk mencari & membaca komik.',
                    style: AppTypography.jakarta(
                      size: 13,
                      weight: FontWeight.w400,
                      height: 1.55,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _label('Nama Sumber'),
                  const SizedBox(height: 8),
                  _input(
                    controller: _nameController,
                    hint: 'cth. KomikStation',
                  ),
                  const SizedBox(height: 18),
                  _label('URL Website Komik'),
                  const SizedBox(height: 8),
                  _input(
                    controller: _urlController,
                    hint: 'https://…',
                    mono: true,
                  ),
                  const SizedBox(height: 6),
                  _buildTestResult(),
                  _label('Bahasa'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _langSegment('Indonesia', 'ID')),
                      const SizedBox(width: 8),
                      Expanded(child: _langSegment('English', 'EN')),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text.rich(
                    TextSpan(
                      text: 'Deskripsi ',
                      style: AppTypography.jakarta(
                        size: 12.5,
                        weight: FontWeight.w700,
                        color: AppColors.menuIcon,
                      ),
                      children: [
                        TextSpan(
                          text: '(opsional)',
                          style: AppTypography.jakarta(
                            size: 12.5,
                            weight: FontWeight.w500,
                            color: AppColors.textFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _input(
                    controller: _descController,
                    hint: 'Catatan singkat tentang sumber ini…',
                    multiline: true,
                  ),
                ],
              ),
            ),
            // Footer action bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
              decoration: const BoxDecoration(
                color: AppColors.bg,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _testSource,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0x1A1E88C8),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0x661E88C8)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_testState == _TestState.loading) ...[
                              const AppSpinner(
                                size: 16,
                                strokeWidth: 2,
                                color: AppColors.accentText,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              _testState == _TestState.loading
                                  ? 'Menguji…'
                                  : 'Test Sumber',
                              style: AppTypography.jakarta(
                                size: 14.5,
                                weight: FontWeight.w700,
                                color: AppColors.accentText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: InkWell(
                      onTap: _canSave ? _saveSource : null,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _canSave
                              ? AppColors.accent
                              : AppColors.switchTrackOff,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Opacity(
                          opacity: _canSave ? 1 : 0.5,
                          child: Text(
                            _isEdit ? 'Simpan Perubahan' : 'Simpan Sumber',
                            style: AppTypography.jakarta(
                              size: 14.5,
                              weight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestResult() {
    switch (_testState) {
      case _TestState.ok:
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              const Icon(
                AppIcons.downloaded,
                size: 15,
                color: AppColors.success,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _repoMatch != null
                      ? 'Cocok dengan ${_repoMatch!.source.name} di repository · akan memakai extension runtime'
                      : _detectedParserKind != null
                      ? 'Struktur situs terdeteksi cocok · bisa dibaca otomatis'
                      : 'Website dapat diakses · preview siap',
                  style: AppTypography.jakarta(
                    size: 12,
                    weight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
        );
      case _TestState.error:
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  AppIcons.errorCircle,
                  size: 15,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tidak bisa diakses. Kamu tetap bisa simpan sebagai sumber '
                  'manual (Web View).',
                  style: AppTypography.jakarta(
                    size: 12,
                    weight: FontWeight.w600,
                    height: 1.4,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
        );
      case _TestState.idle || _TestState.loading:
        return const SizedBox(height: 14);
    }
  }

  Widget _label(String text) => Text(
    text,
    style: AppTypography.jakarta(
      size: 12.5,
      weight: FontWeight.w700,
      color: AppColors.menuIcon,
    ),
  );

  Widget _input({
    required TextEditingController controller,
    required String hint,
    bool mono = false,
    bool multiline = false,
  }) {
    final style = mono
        ? AppTypography.mono(size: 13.5, color: AppColors.textPrimary)
        : AppTypography.jakarta(
            size: multiline ? 14 : 14.5,
            weight: FontWeight.w400,
          );
    return Container(
      height: multiline ? 80 : 50,
      padding: EdgeInsets.symmetric(
        horizontal: 15,
        vertical: multiline ? 12 : 0,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.sheetTopBorder),
      ),
      alignment: multiline ? Alignment.topLeft : Alignment.centerLeft,
      child: TextField(
        controller: controller,
        cursorColor: AppColors.accent,
        style: style,
        maxLines: multiline ? 3 : 1,
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: hint,
          hintStyle:
              (mono
                      ? AppTypography.mono(size: 13.5)
                      : AppTypography.jakarta(
                          size: multiline ? 14 : 14.5,
                          weight: FontWeight.w400,
                        ))
                  .copyWith(color: AppColors.textFaint),
        ),
      ),
    );
  }

  Widget _langSegment(String label, String value) {
    final active = _lang == value;
    return InkWell(
      onTap: () => setState(() => _lang = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? const Color(0x241E88C8) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? const Color(0x801E88C8) : AppColors.sheetTopBorder,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.jakarta(
            size: 13.5,
            weight: FontWeight.w700,
            color: active ? AppColors.accentText : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Tombol back header 40×40 r12 (`surfaceAlt`) — dipakai semua layar pushed.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(AppIcons.back, size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
