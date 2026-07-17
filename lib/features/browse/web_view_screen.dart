import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/extension_runtime.dart';
import '../../data/source_session_store.dart';
import '../../data/sources_state.dart';

const _chromeBg = Color(0xFF141019);

/// WebView Session Mode — spek 10.
///
/// Situs sumber ASLI dibuka lewat `webview_flutter` (bukan mock lagi) —
/// jalan pintas kalau parser native gagal/situs berubah struktur, atau
/// kalau situsnya memang butuh verifikasi manual (login/challenge browser).
///
/// Catatan produk (hard requirement dari spek): TIDAK ADA bypass otomatis —
/// tanpa auto CAPTCHA solve, tanpa spoof fingerprint, tanpa rotasi proxy.
/// "Session aktif" murni ditandai MANUAL oleh user sendiri lewat tombol di
/// bawah, bukan dideteksi otomatis dari isi halaman.
class WebViewScreen extends ConsumerStatefulWidget {
  const WebViewScreen({super.key, required this.sourceId, this.fallbackSource});

  final String sourceId;
  final ComicSource? fallbackSource;

  @override
  ConsumerState<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends ConsumerState<WebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  double _progress = 0;
  String _currentUrl = '';
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _sessionCaptured = false;

  ComicSource? get _source {
    final sources = ref.watch(sourcesProvider);
    for (final s in sources) {
      if (s.id == widget.sourceId) return s;
    }
    return widget.fallbackSource;
  }

  @override
  void initState() {
    super.initState();
    final source =
        ref
            .read(sourcesProvider)
            .where((s) => s.id == widget.sourceId)
            .firstOrNull ??
        widget.fallbackSource;
    final startUrl = source != null ? _webUrl(source.url) : 'about:blank';
    _currentUrl = startUrl;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (!mounted) return;
            setState(() => _progress = p / 100);
          },
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _currentUrl = url;
            });
          },
          onPageFinished: (url) async {
            final back = await _controller.canGoBack();
            final fwd = await _controller.canGoForward();
            if (!mounted) return;
            setState(() {
              _loading = false;
              _currentUrl = url;
              _canGoBack = back;
              _canGoForward = fwd;
            });
          },
          onWebResourceError: (_) {
            if (!mounted) return;
            setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(startUrl));
  }

  Future<void> _reload() => _controller.reload();

  Future<void> _goBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _goForward() async {
    if (await _controller.canGoForward()) await _controller.goForward();
  }

  Future<void> _markSessionActive() async {
    final source = _source;
    if (source == null) return;
    try {
      final session = await const ExtensionRuntimeBridge().readWebViewSession(
        _currentUrl,
      );
      await SourceSessionStore.save(
        url: _currentUrl,
        cookie: session.cookie,
        userAgent: session.userAgent,
      );
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Session browser belum bisa disimpan');
      }
      return;
    }
    if (!mounted) return;
    setState(() => _sessionCaptured = true);
    if (widget.fallbackSource != null) {
      AppToast.show(context, 'Cookie session aktif untuk ${source.name}');
      return;
    }
    ref.read(sourcesProvider.notifier).setSession(source.id, true);
    AppToast.show(context, 'Cookie session tersimpan untuk ${source.name}');
  }

  String _webUrl(String raw) {
    final value = raw.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return 'https://$value';
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    final sessionActive = (source?.session ?? false) || _sessionCaptured;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _goBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top bar
            Container(
              color: _chromeBg,
              padding: EdgeInsets.fromLTRB(
                12,
                MediaQuery.paddingOf(context).top + 6,
                12,
                10,
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(10),
                    child: const SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        AppIcons.back,
                        size: 20,
                        color: AppColors.menuIcon,
                      ),
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
                          Icon(
                            _currentUrl.startsWith('https')
                                ? LucideIcons.lock
                                : LucideIcons.globe,
                            size: 13,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _currentUrl,
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
                    onTap: _reload,
                    borderRadius: BorderRadius.circular(10),
                    child: const SizedBox(
                      width: 34,
                      height: 34,
                      child: Icon(
                        LucideIcons.rotateCw,
                        size: 17,
                        color: AppColors.menuIcon,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_loading)
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                minHeight: 2,
                backgroundColor: _chromeBg,
                color: AppColors.accent,
              ),
            if (sessionActive && !_loading)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: const BoxDecoration(
                  color: Color(0x1A34D399),
                  border: Border(bottom: BorderSide(color: Color(0x3334D399))),
                ),
                child: Row(
                  children: [
                    const Icon(
                      AppIcons.downloaded,
                      size: 14,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Session browser aktif untuk request source ini',
                      style: AppTypography.jakarta(
                        size: 12,
                        weight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            // Body: WebView asli.
            Expanded(child: WebViewWidget(controller: _controller)),
            // Bottom action bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
              decoration: const BoxDecoration(
                color: _chromeBg,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  _navButton(AppIcons.back, _canGoBack ? _goBack : null),
                  const SizedBox(width: 10),
                  _navButton(
                    AppIcons.forward,
                    _canGoForward ? _goForward : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: sessionActive ? null : _markSessionActive,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: sessionActive
                              ? AppColors.switchTrackOff
                              : AppColors.accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              sessionActive
                                  ? AppIcons.downloaded
                                  : LucideIcons.shieldCheck,
                              size: 17,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              sessionActive
                                  ? 'Session Sudah Aktif'
                                  : 'Tandai Session Aktif',
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
      ),
    );
  }

  Widget _navButton(IconData icon, VoidCallback? onTap) {
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
        child: Icon(
          icon,
          size: 18,
          color: onTap == null
              ? AppColors.menuIcon.withValues(alpha: 0.35)
              : AppColors.menuIcon,
        ),
      ),
    );
  }
}
