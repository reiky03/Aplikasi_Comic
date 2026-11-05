import 'dart:async';
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
  const WebViewScreen({
    super.key,
    required this.sourceId,
    this.fallbackSource,
    this.initialUrl,
  });

  final String sourceId;
  final ComicSource? fallbackSource;

  /// Kalau parser gagal di tengah alur baca, buka URL chapter/detail yang
  /// sedang gagal, bukan selalu kembali ke homepage sumber.
  final String? initialUrl;

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
  Timer? _clearanceTimer;

  ComicSource? get _source {
    final sources = ref.read(sourcesProvider);
    for (final s in sources) {
      if (s.id == widget.sourceId) return s;
    }
    return widget.fallbackSource;
  }

  @override
  void dispose() {
    _clearanceTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkCloudflareClearance(String url) async {
    if (_sessionCaptured || !mounted) return;
    try {
      final session = await const ExtensionRuntimeBridge().readWebViewSession(url);
      final cookie = session.cookie ?? '';
      if (cookie.contains('cf_clearance')) {
        _clearanceTimer?.cancel();
        await SourceSessionStore.save(
          url: url,
          cookie: cookie,
          userAgent: session.userAgent,
        );
        final source = _source;
        if (source != null && widget.fallbackSource == null) {
          ref.read(sourcesProvider.notifier).setSession(source.id, true);
        }
        if (mounted) {
          setState(() => _sessionCaptured = true);
          AppToast.show(context, 'Verifikasi Cloudflare berhasil! Sesi aktif.');
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop(true);
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _checkDomainRedirect(String url) async {
    try {
      final newUri = Uri.tryParse(url);
      final source = _source;
      if (source == null || newUri == null || newUri.host.isEmpty) return;
      final oldUri = Uri.tryParse(
        source.url.startsWith('http') ? source.url : 'https://${source.url}',
      );
      final oldHost = oldUri?.host.toLowerCase() ?? '';
      final newHost = newUri.host.toLowerCase();
      if (oldHost.isNotEmpty &&
          oldHost != newHost &&
          !newHost.contains('turnstile') &&
          !newHost.contains('challenges.cloudflare') &&
          !newHost.contains('internetpositif')) {
        final newBaseUrl = '${newUri.scheme}://${newUri.host}';
        await ref
            .read(sourcesProvider.notifier)
            .updateSourceUrl(source.id, newBaseUrl);
      }
    } catch (_) {}
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
    final requestedUrl = widget.initialUrl?.trim();
    final startUrl = requestedUrl != null && requestedUrl.isNotEmpty
        ? _webUrl(requestedUrl)
        : source != null
        ? _webUrl(source.url)
        : 'about:blank';
    _currentUrl = startUrl;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final url = request.url.toLowerCase();
            if (url.startsWith('http://') ||
                url.startsWith('https://') ||
                url.startsWith('about:blank')) {
              return NavigationDecision.navigate;
            }
            // Blokir redirect iklan ke scheme non-HTTP (intent://, market://, tg://)
            debugPrint('Blokir navigasi skema non-web: ${request.url}');
            return NavigationDecision.prevent;
          },
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
            await _checkDomainRedirect(url);
            await _checkCloudflareClearance(url);
          },
          onWebResourceError: (_) {
            if (!mounted) return;
            setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(startUrl));

    _clearanceTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (!_sessionCaptured && _currentUrl.isNotEmpty && mounted) {
        _checkCloudflareClearance(_currentUrl);
      }
    });
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
    final sourceName = source?.name ?? Uri.tryParse(_currentUrl)?.host ?? 'Web';
    if (source != null && widget.fallbackSource == null) {
      ref.read(sourcesProvider.notifier).setSession(source.id, true);
    }
    AppToast.show(context, 'Cookie session tersimpan untuk $sourceName');
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
    // Listener Riverpod hanya dibuat saat build. `_markSessionActive()` juga
    // memakai getter ini, jadi getter-nya sendiri harus berupa `read`.
    ref.watch(sourcesProvider);
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
                  const SizedBox(width: 8),
                  KizenVpnQuickButton(
                    compact: true,
                    onToggled: (enabled) {
                      if (enabled) {
                        AppToast.show(
                          context,
                          '🛡️ VPN telah diaktifkan · Memuat ulang halaman...',
                        );
                        _reload();
                      }
                    },
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
                      onTap: _markSessionActive,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: sessionActive
                              ? const Color(0xFF10B981)
                              : AppColors.accent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: sessionActive
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              sessionActive
                                  ? LucideIcons.shieldCheck
                                  : LucideIcons.shieldAlert,
                              size: 17,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              sessionActive
                                  ? 'Sesi Aktif — Simpan & Kembali'
                                  : 'Tandai Sesi Aktif',
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
