import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/sources_state.dart';
import '../../sources/source_catalog.dart';

enum _TestState { idle, loading, ok, error }

/// Add Source URL — spek 09.
class AddSourceScreen extends ConsumerStatefulWidget {
  const AddSourceScreen({super.key});

  @override
  ConsumerState<AddSourceScreen> createState() => _AddSourceScreenState();
}

class _AddSourceScreenState extends ConsumerState<AddSourceScreen> {
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _descController = TextEditingController();
  String _lang = 'ID';
  _TestState _testState = _TestState.idle;

  @override
  void initState() {
    super.initState();
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
  /// komik populer. Situs lain (di luar daftar) pakai simulasi prototipe
  /// ~1.3s — tetap bisa disimpan sebagai sumber manual (Web View).
  Future<void> _testSource() async {
    if (_testState == _TestState.loading) return;
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    setState(() => _testState = _TestState.loading);

    final source = SourceCatalog.matchByUrl(url);
    if (source != null) {
      try {
        await source.fetchPopular(1);
        if (!mounted) return;
        setState(() => _testState = _TestState.ok);
      } catch (_) {
        if (!mounted) return;
        setState(() => _testState = _TestState.error);
      }
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    final bad =
        RegExp('error|fail|xxx', caseSensitive: false).hasMatch(url);
    setState(() => _testState = bad ? _TestState.error : _TestState.ok);
  }

  void _saveSource() {
    if (!_canSave) return;
    final cleanUrl = _urlController.text
        .trim()
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceFirst(RegExp(r'/$'), '');
    final sources = ref.read(sourcesProvider);
    if (sources.any((s) => s.url == cleanUrl)) {
      AppToast.show(context, 'Sumber sudah ada');
      return;
    }
    ref.read(sourcesProvider.notifier).add(ComicSource(
          id: 's${DateTime.now().millisecondsSinceEpoch}',
          name: _nameController.text.trim(),
          url: cleanUrl,
          lang: _lang,
          hue: 200 + math.Random().nextInt(140),
          status: _testState == _TestState.ok
              ? SourceStatus.normal
              : SourceStatus.webview,
        ));
    Navigator.of(context).pop();
    AppToast.show(context, 'Sumber ditambahkan');
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
                    'Tambah Sumber',
                    style:
                        AppTypography.jakarta(size: 19, weight: FontWeight.w800),
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
                  _label('Pilih Cepat'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final source in SourceCatalog.sources)
                        _QuickPickChip(
                          label: source.name,
                          onTap: () {
                            _nameController.text = source.name;
                            _urlController.text = source.baseUrl;
                            setState(() => _testState = _TestState.idle);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
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
                          border:
                              Border.all(color: const Color(0x661E88C8)),
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
                            'Simpan Sumber',
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
              const Icon(AppIcons.downloaded,
                  size: 15, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Website dapat diakses · preview siap',
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
                child: Icon(AppIcons.errorCircle,
                    size: 15, color: AppColors.danger),
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
            size: multiline ? 14 : 14.5, weight: FontWeight.w400);
    return Container(
      height: multiline ? 80 : 50,
      padding: EdgeInsets.symmetric(
          horizontal: 15, vertical: multiline ? 12 : 0),
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
          hintStyle: (mono
                  ? AppTypography.mono(size: 13.5)
                  : AppTypography.jakarta(
                      size: multiline ? 14 : 14.5, weight: FontWeight.w400))
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
            color:
                active ? const Color(0x801E88C8) : AppColors.sheetTopBorder,
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

/// Chip "pilih cepat" — isi otomatis Nama+URL dari sumber yang punya
/// parser native (lihat lib/sources/), supaya user tidak perlu ketik URL.
class _QuickPickChip extends StatelessWidget {
  const _QuickPickChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.sheetTopBorder),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.jakarta(
            size: 12.5,
            weight: FontWeight.w700,
            color: AppColors.textSecondary,
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
          child:
              Icon(AppIcons.back, size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
