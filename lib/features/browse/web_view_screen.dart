import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/library_state.dart';
import '../../data/models.dart';
import '../../data/sources_state.dart';

enum _VerifyState { idle, loading, done }

const _chromeBg = Color(0xFF141019);

/// WebView Session Mode — spek 10.
///
/// Body halaman memakai mock demo (sumber demo memakai domain contoh yang
/// tidak resolvable). TODO(webview): saat sumber asli dipakai, ganti body
/// dengan webview_flutter menunjuk URL sumber — chrome, banner session,
/// challenge flow, dan action bar dipertahankan.
///
/// Catatan produk (hard requirement dari spek): TIDAK ADA bypass otomatis —
/// tanpa auto CAPTCHA solve, tanpa spoof fingerprint, tanpa rotasi proxy.
/// Sesi hanya cookie/session normal hasil verifikasi manual user.
class WebViewScreen extends ConsumerStatefulWidget {
  const WebViewScreen({super.key, required this.sourceId});

  final String sourceId;

  @override
  ConsumerState<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends ConsumerState<WebViewScreen> {
  _VerifyState _verify = _VerifyState.idle;
  late bool _challengeOn;

  ComicSource? get _source {
    final sources = ref.watch(sourcesProvider);
    for (final s in sources) {
      if (s.id == widget.sourceId) return s;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final sources = ref.read(sourcesProvider);
    final source =
        sources.where((s) => s.id == widget.sourceId).firstOrNull;
    // Challenge hanya saat belum ada sesi & status bukan normal.
    _challengeOn = source != null &&
        !source.session &&
        source.status != SourceStatus.normal;
  }

  /// Simulasi verifikasi manual. Timing prototipe ~1.4s.
  Future<void> _verifyChallenge() async {
    if (_verify != _VerifyState.idle) return;
    setState(() => _verify = _VerifyState.loading);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    final source = _source;
    setState(() {
      _verify = _VerifyState.done;
      _challengeOn = false;
    });
    if (source != null) {
      ref.read(sourcesProvider.notifier).setSession(source.id, true);
      AppToast.show(context, 'Session tersimpan untuk ${source.name}');
    }
  }

  void _saveWebComic() {
    final source = _source;
    ref.read(libraryProvider.notifier).add(Comic(
          id: 'w${DateTime.now().millisecondsSinceEpoch}',
          title: 'Void Chronicles',
          src: source?.name ?? 'Web',
          hue: 350,
          ch: 88,
        ));
    AppToast.show(context, 'Disimpan ke Library dari Web View');
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    final sessionActive = source?.session ?? false;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top bar
          Container(
            color: _chromeBg,
            padding: EdgeInsets.fromLTRB(
                12, MediaQuery.paddingOf(context).top + 6, 12, 10),
            child: Row(
              children: [
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(10),
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(AppIcons.back,
                        size: 20, color: AppColors.menuIcon),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B0B0F),
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(color: AppColors.sheetTopBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.lock,
                            size: 13, color: AppColors.success),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            source?.url ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.mono(
                              size: 12.5,
                              color: const Color(0xFFB9B9C6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () =>
                      AppToast.show(context, 'Daftar komik diperbarui'),
                  borderRadius: BorderRadius.circular(10),
                  child: const SizedBox(
                    width: 34,
                    height: 34,
                    child: Icon(LucideIcons.rotateCw,
                        size: 17, color: AppColors.menuIcon),
                  ),
                ),
                InkWell(
                  onTap: () {},
                  borderRadius: BorderRadius.circular(10),
                  child: const SizedBox(
                    width: 30,
                    height: 34,
                    child: Icon(AppIcons.more,
                        size: 17, color: AppColors.menuIcon),
                  ),
                ),
              ],
            ),
          ),
          if (sessionActive && !_challengeOn)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0x1A34D399),
                border:
                    Border(bottom: BorderSide(color: Color(0x3334D399))),
              ),
              child: Row(
                children: [
                  const Icon(AppIcons.downloaded,
                      size: 14, color: AppColors.success),
                  const SizedBox(width: 8),
                  Text(
                    'Session aktif · verifikasi tersimpan untuk source ini',
                    style: AppTypography.jakarta(
                      size: 12,
                      weight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          // Body: halaman web (mock demo) + overlay challenge
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                const _MockWebPage(),
                if (_challengeOn)
                  _ChallengeOverlay(
                    url: source?.url ?? '',
                    state: _verify,
                    onVerify: _verifyChallenge,
                  ),
              ],
            ),
          ),
          // Bottom action bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
            decoration: const BoxDecoration(
              color: _chromeBg,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                _navButton(AppIcons.back, () {}),
                const SizedBox(width: 10),
                _navButton(AppIcons.forward, () {}),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: _saveWebComic,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(AppIcons.bookmark,
                              size: 17, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Simpan ke Library',
                            style: AppTypography.jakarta(
                              size: 13.5,
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
        ],
      ),
    );
  }

  Widget _navButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Icon(icon, size: 18, color: AppColors.menuIcon),
      ),
    );
  }
}

/// Overlay interstisial challenge (meniru halaman verifikasi website —
/// karena itu bergaya terang, bukan chrome app).
class _ChallengeOverlay extends StatelessWidget {
  const _ChallengeOverlay({
    required this.url,
    required this.state,
    required this.onVerify,
  });

  final String url;
  final _VerifyState state;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F4F6),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE0E0E6)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4D000000),
                  offset: Offset(0, 8),
                  blurRadius: 24,
                  spreadRadius: -12,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(LucideIcons.shield,
                size: 30, color: Color(0xFF123A5C)),
          ),
          const SizedBox(height: 20),
          Text(
            'Memeriksa keamanan koneksi',
            style: AppTypography.jakarta(
              size: 16,
              weight: FontWeight.w800,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 250),
            child: Text(
              '$url meminta verifikasi bahwa kamu bukan bot sebelum '
              'melanjutkan.',
              textAlign: TextAlign.center,
              style: AppTypography.jakarta(
                size: 12.5,
                weight: FontWeight.w400,
                height: 1.5,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: onVerify,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 280),
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD5D7DD)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    offset: Offset(0, 4),
                    blurRadius: 14,
                    spreadRadius: -8,
                  ),
                ],
              ),
              child: Row(
                children: [
                  switch (state) {
                    _VerifyState.idle => Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFFB8BBC4), width: 2),
                        ),
                      ),
                    _VerifyState.loading => const AppSpinner(
                        size: 24,
                        strokeWidth: 2.5,
                        color: Color(0xFF123A5C),
                      ),
                    _VerifyState.done => Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(AppIcons.downloaded,
                            size: 15, color: Colors.white),
                      ),
                  },
                  const SizedBox(width: 12),
                  Text(
                    switch (state) {
                      _VerifyState.idle => 'Saya bukan robot',
                      _VerifyState.loading => 'Memverifikasi…',
                      _VerifyState.done => 'Terverifikasi',
                    },
                    style: AppTypography.jakarta(
                      size: 14,
                      weight: FontWeight.w600,
                      color: switch (state) {
                        _VerifyState.idle => const Color(0xFF1A1A1A),
                        _VerifyState.loading => const Color(0xFF6B7280),
                        _VerifyState.done => const Color(0xFF16A34A),
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 250),
            child: Text(
              'Verifikasi diselesaikan manual di WebView. Kizen tidak '
              'melakukan bypass otomatis.',
              textAlign: TextAlign.center,
              style: AppTypography.jakarta(
                size: 10.5,
                weight: FontWeight.w400,
                height: 1.5,
                color: const Color(0xFF9CA3AF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mock halaman web demo "KOMIK·STATION" (persis prototipe).
class _MockWebPage extends StatelessWidget {
  const _MockWebPage();

  static const _maroon = Color(0xFF7A1F2B);

  @override
  Widget build(BuildContext context) {
    const entries = [
      ('Void Chronicles', 'Ch. 88 · baru', [Color(0xFFC94B57), Color(0xFF7A1F2B)]),
      ('Iron Petals', 'Ch. 40 · baru', [Color(0xFF4B7BC9), Color(0xFF1F2F7A)]),
      ('Ghostlight', 'Ch. 12 · baru', [Color(0xFF4BC98A), Color(0xFF1F7A4F)]),
      ('Duskbound', 'Ch. 5 · baru', [Color(0xFFC9A24B), Color(0xFF7A5B1F)]),
    ];

    return Container(
      color: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            color: _maroon,
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'KOMIK·STATION',
                  style: AppTypography.jakarta(
                    size: 18,
                    weight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
                const Opacity(
                  opacity: 0.8,
                  child: Icon(Icons.menu, size: 18, color: Colors.white),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.only(bottom: 8),
                  decoration: const BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: _maroon, width: 2)),
                  ),
                  child: Text(
                    'Update Terbaru',
                    style: AppTypography.jakarta(
                      size: 15,
                      weight: FontWeight.w800,
                      color: _maroon,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.62,
                  children: [
                    for (final (title, ch, colors) in entries)
                      Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: const Color(0xFFE4E4E4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: colors,
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: AppTypography.jakarta(
                                      size: 12,
                                      weight: FontWeight.w700,
                                      color: const Color(0xFF222222),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    ch,
                                    style: AppTypography.jakarta(
                                      size: 10.5,
                                      weight: FontWeight.w400,
                                      color: const Color(0xFFC94B57),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
