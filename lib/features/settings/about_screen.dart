import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_update_checker.dart';
import '../../data/extension_runtime.dart';

const _appVersion = '1.2.4';
const _appBuild = '16';
const _repoOwner = 'reiky03';
const _developerHandle = '@reiky03';

/// Identitas aplikasi, pengembang, pembaruan, dan lisensi.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  bool _checking = false;

  Future<void> _openUrl(String url) async {
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) AppToast.show(context, 'Gagal membuka link');
    } catch (_) {
      // Tidak ada browser/app yang bisa handle link ini, atau (di web
      // headless/sandbox) popup diblokir — jangan sampai nge-crash,
      // cukup kasih tau apa adanya.
      if (mounted) AppToast.show(context, 'Gagal membuka link');
    }
  }

  Future<void> _checkForUpdate() async {
    if (_checking) return;
    setState(() => _checking = true);
    final result = await checkForAppUpdate(currentVersion: _appVersion);
    if (!mounted) return;
    setState(() => _checking = false);
    if (result.hasUpdate) {
      await showAppSheet<void>(
        context,
        builder: (sheetContext) => _AppUpdateSheet(
          result: result,
          currentVersion: _appVersion,
          onOpenUrl: _openUrl,
        ),
      );
    } else {
      AppToast.show(context, result.message ?? 'Sudah pakai versi terbaru');
    }
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
                  _BackButton(onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 8),
                  Text(
                    'Tentang',
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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Center(
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/branding/kizen_mark.png',
                            width: 72,
                            height: 72,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Kizen',
                          style: AppTypography.jakarta(
                            size: 20,
                            weight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'v$_appVersion (build $_appBuild)',
                          style: AppTypography.jakarta(
                            size: 12.5,
                            weight: FontWeight.w400,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Pembaca komik lintas sumber',
                          style: AppTypography.jakarta(
                            size: 12,
                            weight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  _eyebrow('Developer'),
                  _card([
                    _row(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF1E88C8), Color(0xFF123A5C)],
                          ),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'R',
                          style: AppTypography.jakarta(
                            size: 16,
                            weight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      title: _developerHandle,
                      subtitle: 'GitHub',
                      trailing: const Icon(
                        AppIcons.forward,
                        size: 16,
                        color: AppColors.textFaint,
                      ),
                      onTap: () => _openUrl('https://github.com/$_repoOwner'),
                      showDivider: false,
                    ),
                  ]),
                  _eyebrow('Aplikasi'),
                  _card([
                    _menuRow(
                      icon: LucideIcons.refreshCw,
                      label: 'Periksa pembaruan',
                      trailing: _checking
                          ? const AppSpinner(size: 18, strokeWidth: 2)
                          : const Icon(
                              AppIcons.forward,
                              size: 16,
                              color: AppColors.textFaint,
                            ),
                      onTap: _checking ? null : _checkForUpdate,
                    ),
                    _menuRow(
                      icon: LucideIcons.fileText,
                      label: 'Lisensi open source',
                      trailing: const Icon(
                        AppIcons.forward,
                        size: 16,
                        color: AppColors.textFaint,
                      ),
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: 'Kizen',
                        applicationVersion: 'v$_appVersion ($_appBuild)',
                        applicationIcon: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Image.asset(
                            'assets/branding/kizen_mark.png',
                            width: 56,
                            height: 56,
                          ),
                        ),
                      ),
                      showDivider: false,
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eyebrow(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
    child: Text(text.toUpperCase(), style: AppTypography.eyebrow),
  );

  Widget _card(List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 22),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(children: children),
  );

  Widget _row({
    required Widget leading,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
    bool showDivider = true,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: showDivider
            ? const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.sheetRowDivider),
                ),
              )
            : null,
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.jakarta(
                      size: 14,
                      weight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.jakarta(
                      size: 12,
                      weight: FontWeight.w400,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _menuRow({
    required IconData icon,
    required String label,
    required Widget trailing,
    VoidCallback? onTap,
    bool showDivider = true,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: showDivider
            ? const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.sheetRowDivider),
                ),
              )
            : null,
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.accentText),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTypography.jakarta(size: 14, weight: FontWeight.w600),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

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

class _AppUpdateSheet extends StatefulWidget {
  const _AppUpdateSheet({
    required this.result,
    required this.currentVersion,
    required this.onOpenUrl,
  });

  final AppUpdateResult result;
  final String currentVersion;
  final ValueChanged<String> onOpenUrl;

  @override
  State<_AppUpdateSheet> createState() => _AppUpdateSheetState();
}

class _AppUpdateSheetState extends State<_AppUpdateSheet> {
  final _bridge = const ExtensionRuntimeBridge();
  bool _isDownloading = false;
  double _progress = 0.0;
  int _received = 0;
  int _total = 0;
  bool _completed = false;
  String? _errorMessage;

  @override
  void dispose() {
    if (_isDownloading) {
      _bridge.cancelUpdateDownload();
    }
    super.dispose();
  }

  Future<void> _startDownloadAndInstall() async {
    final apkUrl = widget.result.apkUrl;
    if (apkUrl == null || apkUrl.isEmpty) {
      final releaseUrl = widget.result.releaseUrl;
      if (releaseUrl != null) widget.onOpenUrl(releaseUrl);
      return;
    }

    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (!isAndroid) {
      final releaseUrl = widget.result.releaseUrl;
      if (releaseUrl != null) widget.onOpenUrl(releaseUrl);
      return;
    }

    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0.0;
      _received = 0;
      _total = widget.result.apkSize ?? 0;
      _completed = false;
    });

    final fileName =
        widget.result.apkName ?? 'kizen-v${widget.result.latestVersion}.apk';

    try {
      await _bridge.downloadAndInstallAppUpdate(
        apkUrl: apkUrl,
        fileName: fileName,
        onProgress: (received, total, completed) {
          if (!mounted) return;
          setState(() {
            _received = received;
            if (total > 0) _total = total;
            _progress =
                _total > 0 ? (_received / _total).clamp(0.0, 1.0) : 0.0;
            if (completed) {
              _completed = true;
              _isDownloading = false;
            }
          });
        },
      );
      if (mounted) {
        setState(() {
          _completed = true;
          _isDownloading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage =
              e.toString().replaceFirst(RegExp(r'^Exception: '), '');
        });
      }
    }
  }

  Future<void> _reopenInstaller() async {
    final fileName =
        widget.result.apkName ?? 'kizen-v${widget.result.latestVersion}.apk';
    final ok = await _bridge.openDownloadedUpdateInstaller(fileName: fileName);
    if (!ok && mounted) {
      AppToast.show(context, 'Gagal membuka installer. Coba unduh ulang.');
      setState(() => _completed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final res = widget.result;
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final sizeMb = res.apkSize != null
        ? (res.apkSize! / (1024 * 1024)).toStringAsFixed(1)
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                LucideIcons.packageCheck,
                size: 20,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSheetTitle('Pembaruan Tersedia', bottomGap: 2),
                  Text(
                    'Kizen v${res.latestVersion} (kamu v${widget.currentVersion})${sizeMb != null ? ' • $sizeMb MB' : ''}',
                    style: AppTypography.jakarta(
                      size: 12.5,
                      weight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (res.releaseNotes != null && res.releaseNotes!.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'YANG BARU',
            style: AppTypography.eyebrow,
          ),
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 160),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: SingleChildScrollView(
              child: Text(
                res.releaseNotes!.trim(),
                style: AppTypography.jakarta(
                  size: 12,
                  weight: FontWeight.w400,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (_isDownloading) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const AppSpinner(size: 14, strokeWidth: 2),
                        const SizedBox(width: 8),
                        Text(
                          'Mengunduh APK...',
                          style: AppTypography.jakarta(
                            size: 12.5,
                            weight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${(_progress * 100).toStringAsFixed(0)}%',
                      style: AppTypography.jakarta(
                        size: 13,
                        weight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    minHeight: 7,
                    backgroundColor: AppColors.bg,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.accent),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${(_received / (1024 * 1024)).toStringAsFixed(1)} MB / ${_total > 0 ? (_total / (1024 * 1024)).toStringAsFixed(1) : '?'} MB',
                  textAlign: TextAlign.right,
                  style: AppTypography.jakarta(
                    size: 11,
                    weight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ] else if (_completed) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.circleCheckBig,
                  size: 18,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Unduhan selesai! Membuka installer Android...',
                    style: AppTypography.jakarta(
                      size: 12,
                      weight: FontWeight.w500,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ] else if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.triangleAlert,
                  size: 18,
                  color: Colors.redAccent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Gagal mengunduh: $_errorMessage',
                    style: AppTypography.jakarta(
                      size: 12,
                      weight: FontWeight.w400,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (_completed)
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _reopenInstaller,
              icon: const Icon(LucideIcons.packageCheck, size: 18),
              label: const Text('Buka Installer Kembali'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _isDownloading
                  ? null
                  : (isAndroid && res.apkUrl != null
                      ? _startDownloadAndInstall
                      : () {
                          Navigator.pop(context);
                          if (res.releaseUrl != null) {
                            widget.onOpenUrl(res.releaseUrl!);
                          }
                        }),
              icon: Icon(
                _isDownloading
                    ? LucideIcons.refreshCw
                    : (isAndroid && res.apkUrl != null
                        ? LucideIcons.download
                        : LucideIcons.externalLink),
                size: 18,
              ),
              label: Text(
                _isDownloading
                    ? 'Sedang Mengunduh...'
                    : (isAndroid && res.apkUrl != null
                        ? 'Unduh & Pasang Langsung'
                        : 'Buka Halaman Rilis'),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.surfaceAlt,
                disabledForegroundColor: AppColors.textMuted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              if (res.releaseUrl != null) widget.onOpenUrl(res.releaseUrl!);
            },
            icon: const Icon(LucideIcons.externalLink, size: 16),
            label: const Text('Lihat Halaman Rilis di GitHub'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
