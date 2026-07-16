import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/repository_state.dart';
import 'add_source_screen.dart';
import 'browse_screen.dart';

/// Repository List ("Repository Saya") — spek 11.
class RepositoryListScreen extends ConsumerWidget {
  const RepositoryListScreen({super.key});

  void _openAdd(BuildContext context, {ComicRepository? repo}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddRepositoryScreen(editing: repo),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repositories = ref.watch(repositoriesProvider);

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
                  Expanded(
                    child: Text(
                      'Repository Saya',
                      style: AppTypography.jakarta(
                          size: 19, weight: FontWeight.w800),
                    ),
                  ),
                  Material(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => _openAdd(context),
                      borderRadius: BorderRadius.circular(12),
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(AppIcons.add,
                            size: 19, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: repositories.isEmpty
                  ? AppEmptyState(
                      icon: const CustomPaint(
                        size: Size.square(42),
                        painter: RepoGlyphPainter(
                            color: AppColors.emptyIcon, strokeWidth: 1.7),
                      ),
                      title: 'Belum ada repository',
                      description: TextSpan(
                        children: [
                          const TextSpan(text: 'Tekan tombol '),
                          TextSpan(
                            text: '+',
                            style: AppTypography.jakarta(
                              size: 13.5,
                              weight: FontWeight.w700,
                              color: AppColors.accentText,
                            ),
                          ),
                          const TextSpan(
                              text:
                                  ' di pojok kanan untuk menambah repository baru.'),
                        ],
                      ),
                      ctaLabel: 'Tambah Repository',
                      onCta: () => _openAdd(context),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(18, 6, 18, 40),
                      children: [
                        for (final repo in repositories)
                          _RepoRow(
                            repo: repo,
                            onEdit: () => _openAdd(context, repo: repo),
                            onDelete: () {
                              ref
                                  .read(repositoriesProvider.notifier)
                                  .remove(repo.id);
                              AppToast.show(context, 'Repository dihapus');
                            },
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepoRow extends StatelessWidget {
  const _RepoRow({
    required this.repo,
    required this.onEdit,
    required this.onDelete,
  });

  final ComicRepository repo;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0x241E88C8),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const CustomPaint(
              size: Size.square(20),
              painter: RepoGlyphPainter(color: AppColors.accentText),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  repo.name,
                  style:
                      AppTypography.jakarta(size: 14.5, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  repo.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.jakarta(
                    size: 11.5,
                    weight: FontWeight.w400,
                    color: AppColors.textFaintestAlt,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${repo.sources.length} sumber',
                  style: AppTypography.jakarta(
                    size: 11,
                    weight: FontWeight.w600,
                    color: AppColors.accentText,
                  ),
                ),
              ],
            ),
          ),
          _iconAction(
            icon: AppIcons.edit,
            color: AppColors.menuIcon,
            borderColor: AppColors.borderStrong,
            onTap: onEdit,
          ),
          const SizedBox(width: 8),
          _iconAction(
            icon: AppIcons.delete,
            color: AppColors.danger,
            borderColor: AppColors.dangerBorder,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }

  Widget _iconAction({
    required IconData icon,
    required Color color,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }
}

enum _RepoTestState { idle, loading, ok, error }

/// Add / Edit Repository — spek 11 (satu layar untuk dua mode).
class AddRepositoryScreen extends ConsumerStatefulWidget {
  const AddRepositoryScreen({super.key, this.editing});

  /// Repo yang diedit; null = mode tambah.
  final ComicRepository? editing;

  @override
  ConsumerState<AddRepositoryScreen> createState() =>
      _AddRepositoryScreenState();
}

class _AddRepositoryScreenState extends ConsumerState<AddRepositoryScreen> {
  late final _nameController =
      TextEditingController(text: widget.editing?.name ?? '');
  late final _urlController =
      TextEditingController(text: widget.editing?.url ?? '');
  _RepoTestState _testState = _RepoTestState.idle;
  List<RepoSource> _preview = const [];

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
    _urlController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      _urlController.text.trim().isNotEmpty;

  /// Cek reachability + isi repository. Timing prototipe ~1.3s.
  /// TODO(backend): fetch & parse index repository sungguhan.
  Future<void> _testRepo() async {
    if (_testState == _RepoTestState.loading) return;
    if (_urlController.text.trim().isEmpty) return;
    setState(() => _testState = _RepoTestState.loading);
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    final bad = RegExp('error|fail|xxx', caseSensitive: false)
        .hasMatch(_urlController.text);
    if (bad) {
      setState(() {
        _testState = _RepoTestState.error;
        _preview = const [];
      });
      return;
    }
    const names = [
      'NusaScans', 'KomikRaya', 'MangaLintang', 'InkVerse', 'Duniakomik',
    ];
    final count = 3 + math.Random().nextInt(2);
    setState(() {
      _testState = _RepoTestState.ok;
      _preview = [
        for (var i = 0; i < count; i++)
          RepoSource(
              id: 'prev$i', name: names[i], hue: (i * 70 + 40) % 360, lang: ''),
      ];
    });
  }

  void _saveRepo() {
    if (!_canSave) return;
    final cleanUrl =
        _urlController.text.trim().replaceFirst(RegExp(r'^https?://'), '');
    final name = _nameController.text.trim();

    if (_isEdit) {
      ref
          .read(repositoriesProvider.notifier)
          .update(widget.editing!.id, name: name, url: cleanUrl);
      Navigator.of(context).pop();
      AppToast.show(context, 'Repository diperbarui');
      return;
    }

    // Round-robin bahasa dari pool — placeholder sampai format index
    // repository asli mendefinisikan metadata bahasa per sumber.
    const langPool = ['ID', 'EN', 'JP', 'KR', 'CN'];
    final preview = _preview.isNotEmpty
        ? _preview
        : [
            for (var i = 0; i < 3; i++)
              RepoSource(
                id: 'prev$i',
                name: const ['NusaScans', 'KomikRaya', 'MangaLintang'][i],
                hue: (i * 70 + 40) % 360,
                lang: '',
              ),
          ];
    final now = DateTime.now().millisecondsSinceEpoch;
    ref.read(repositoriesProvider.notifier).add(ComicRepository(
          id: 'rp$now',
          name: name,
          url: cleanUrl,
          sources: [
            for (var i = 0; i < preview.length; i++)
              RepoSource(
                id: 'rps$now${preview[i].id}',
                name: preview[i].name,
                hue: preview[i].hue,
                lang: langPool[i % langPool.length],
              ),
          ],
        ));
    Navigator.of(context).pop();
    AppToast.show(context, 'Repository ditambahkan');
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
                    _isEdit ? 'Edit Repository' : 'Tambah Repository',
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
                    'Repository adalah link yang berisi daftar banyak sumber '
                    'komik sekaligus (seperti daftar extension). Masukkan link '
                    'index repository untuk melihat isinya.',
                    style: AppTypography.jakarta(
                      size: 13,
                      weight: FontWeight.w400,
                      height: 1.55,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _label('Nama Repository'),
                  const SizedBox(height: 8),
                  _input(
                      controller: _nameController,
                      hint: 'cth. Komunitas ID Repo'),
                  const SizedBox(height: 18),
                  _label('URL Index Repository'),
                  const SizedBox(height: 8),
                  _input(
                    controller: _urlController,
                    hint: 'https://…/index.json',
                    mono: true,
                  ),
                  const SizedBox(height: 6),
                  _buildTestResult(),
                  if (_testState == _RepoTestState.ok && !_isEdit) ...[
                    _label('Pratinjau isi repository'),
                    const SizedBox(height: 8),
                    Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          for (final ps in _preview)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 13, vertical: 11),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                      color: AppColors.sheetRowDivider),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      gradient: comicCover(ps.hue),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      ps.initial,
                                      style: AppTypography.jakarta(
                                        size: 13,
                                        weight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 11),
                                  Text(
                                    ps.name,
                                    style: AppTypography.jakarta(
                                        size: 13, weight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
                      onTap: _testRepo,
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
                            if (_testState == _RepoTestState.loading) ...[
                              const AppSpinner(
                                size: 16,
                                strokeWidth: 2,
                                color: AppColors.accentText,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              _testState == _RepoTestState.loading
                                  ? 'Memeriksa…'
                                  : 'Periksa Repository',
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
                      onTap: _canSave ? _saveRepo : null,
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
                            _isEdit ? 'Simpan Perubahan' : 'Tambah Repository',
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
      case _RepoTestState.ok:
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              const Icon(AppIcons.downloaded,
                  size: 15, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ditemukan ${_preview.length} sumber di repository ini',
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
      case _RepoTestState.error:
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
                  'Link repository tidak valid atau tidak bisa diakses.',
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
      case _RepoTestState.idle || _RepoTestState.loading:
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
  }) {
    final style = mono
        ? AppTypography.mono(size: 13.5, color: AppColors.textPrimary)
        : AppTypography.jakarta(size: 14.5, weight: FontWeight.w400);
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.sheetTopBorder),
      ),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        cursorColor: AppColors.accent,
        style: style,
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: (mono
                  ? AppTypography.mono(size: 13.5)
                  : AppTypography.jakarta(size: 14.5, weight: FontWeight.w400))
              .copyWith(color: AppColors.textFaint),
        ),
      ),
    );
  }
}
