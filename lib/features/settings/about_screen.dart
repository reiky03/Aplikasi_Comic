import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_update_checker.dart';

const _appVersion = '1.0.0';
const _appBuild = '1';
const _repoOwner = 'reiky03';
const _repoName = 'Aplikasi_Comic';
const _developerName = 'Reiky Aryanando Pratama';
const _developerHandle = '@reiky03';

/// "Tentang" — spek Setelan, gaya Tachiyomi/Mihon: identitas app, kredit
/// developer, link kode sumber, dan "Periksa pembaruan" (cek rilis GitHub
/// asli, bukan simulasi).
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  bool _checking = false;

  Future<void> _openUrl(String url) async {
    try {
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSheetTitle('Versi baru tersedia', bottomGap: 8),
            Text(
              'Kizen v${result.latestVersion} sudah rilis di GitHub '
              '(kamu sekarang pakai v$_appVersion).',
              style: AppTypography.jakarta(
                size: 13,
                weight: FontWeight.w400,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  final url = result.releaseUrl;
                  if (url != null) _openUrl(url);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Buka halaman rilis'),
              ),
            ),
          ],
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
                  Text('Tentang',
                      style:
                          AppTypography.jakarta(size: 19, weight: FontWeight.w800)),
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
                        Text('Kizen',
                            style: AppTypography.jakarta(
                                size: 20, weight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          'v$_appVersion (build $_appBuild)',
                          style: AppTypography.jakarta(
                            size: 12.5,
                            weight: FontWeight.w400,
                            color: AppColors.textMuted,
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
                              size: 16, weight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                      title: _developerName,
                      subtitle: _developerHandle,
                      trailing: const Icon(AppIcons.forward,
                          size: 16, color: AppColors.textFaint),
                      onTap: () => _openUrl('https://github.com/$_repoOwner'),
                      showDivider: false,
                    ),
                  ]),
                  _eyebrow('Aplikasi'),
                  _card([
                    _menuRow(
                      icon: LucideIcons.folderGit2,
                      label: 'Kode sumber',
                      trailing: const Icon(AppIcons.forward,
                          size: 16, color: AppColors.textFaint),
                      onTap: () => _openUrl(
                          'https://github.com/$_repoOwner/$_repoName'),
                    ),
                    _menuRow(
                      icon: LucideIcons.refreshCw,
                      label: 'Periksa pembaruan',
                      trailing: _checking
                          ? const AppSpinner(size: 18, strokeWidth: 2)
                          : const Icon(AppIcons.forward,
                              size: 16, color: AppColors.textFaint),
                      onTap: _checking ? null : _checkForUpdate,
                      showDivider: false,
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Text(
                    'Kizen dibuat buat kebutuhan baca komik pribadi — bukan '
                    'produk komersial.',
                    textAlign: TextAlign.center,
                    style: AppTypography.jakarta(
                      size: 11,
                      weight: FontWeight.w400,
                      color: AppColors.textFaintest,
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
                border:
                    Border(bottom: BorderSide(color: AppColors.sheetRowDivider)),
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
                  Text(title,
                      style: AppTypography.jakarta(size: 14, weight: FontWeight.w700)),
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
                border:
                    Border(bottom: BorderSide(color: AppColors.sheetRowDivider)),
              )
            : null,
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.accentText),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: AppTypography.jakarta(size: 14, weight: FontWeight.w600)),
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
