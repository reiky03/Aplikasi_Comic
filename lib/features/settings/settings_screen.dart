import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/bookmarks_state.dart';
import '../../data/extension_runtime.dart';
import '../../data/history_state.dart';
import '../../data/library_state.dart';
import '../../data/repository_state.dart';
import '../../data/sources_state.dart';
import '../../data/updates_state.dart';
import '../sync/sync_service.dart';
import '../auth/auth_repository.dart';
import '../onboarding/login_screen.dart';
import '../reader/reader_settings_sheet.dart';
import 'about_screen.dart';

/// Tab Setelan — spek 14.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider);

    final name = user?.name ?? 'Adin Pratama';
    final email = user?.email ?? 'adin.pratama@gmail.com';

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text('Setelan', style: AppTypography.screenTitle),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
              children: [
                // Account card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
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
                          name.isEmpty ? '?' : name[0],
                          style: AppTypography.jakarta(
                            size: 19,
                            weight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: AppTypography.jakarta(
                                size: 15,
                                weight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              email,
                              style: AppTypography.jakarta(
                                size: 12.5,
                                weight: FontWeight.w400,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Tersinkron',
                            style: AppTypography.jakarta(
                              size: 11,
                              weight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _eyebrow('Aplikasi'),
                _card([
                  _menuRow(
                    icon: LucideIcons.moon,
                    label: 'Tema',
                    trailing: Text(
                      'Gelap',
                      style: AppTypography.jakarta(
                        size: 13,
                        weight: FontWeight.w400,
                        color: AppColors.textMuted,
                      ),
                    ),
                    // Dark-first by design, bukan pilihan — tanpa onTap/chevron
                    // supaya gak keliatan kayak tombol yang beneran ganti tema.
                    onTap: null,
                  ),
                  _menuRow(
                    icon: LucideIcons.alignLeft,
                    label: 'Pengaturan Reader',
                    trailing: const Icon(
                      AppIcons.forward,
                      size: 16,
                      color: AppColors.textFaint,
                    ),
                    onTap: () => showReaderSettingsSheet(context),
                  ),
                  _menuRow(
                    icon: LucideIcons.rotateCw,
                    label: 'Sinkronisasi & Cadangan',
                    trailing: const Icon(
                      AppIcons.forward,
                      size: 16,
                      color: AppColors.textFaint,
                    ),
                    onTap: () => _runSync(context, ref),
                  ),
                  _menuRow(
                    icon: LucideIcons.info,
                    label: 'Tentang',
                    trailing: const Icon(
                      AppIcons.forward,
                      size: 16,
                      color: AppColors.textFaint,
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AboutScreen(),
                      ),
                    ),
                    showDivider: false,
                  ),
                ]),
                _eyebrow('Library & Sumber'),
                _card([
                  _menuRow(
                    icon: LucideIcons.refreshCw,
                    label: 'Periksa Update Chapter',
                    trailing: const Icon(
                      AppIcons.forward,
                      size: 16,
                      color: AppColors.textFaint,
                    ),
                    onTap: () => _checkUpdates(context, ref),
                  ),
                  _menuRow(
                    icon: LucideIcons.packageCheck,
                    label: 'Extension Runtime',
                    trailing: const Icon(
                      AppIcons.forward,
                      size: 16,
                      color: AppColors.textFaint,
                    ),
                    onTap: () => _checkExtensionRuntime(context),
                  ),
                  _menuRow(
                    icon: LucideIcons.clock,
                    label: 'Bersihkan History',
                    trailing: const Icon(
                      AppIcons.forward,
                      size: 16,
                      color: AppColors.textFaint,
                    ),
                    onTap: () => _clearHistory(context, ref),
                    showDivider: false,
                  ),
                ]),
                const SizedBox(height: 22),
                InkWell(
                  onTap: () => _signOut(context, ref),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0x14FF5C7A), // rgba(214,66,43,.08)
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x4DFF5C7A)), // .3
                    ),
                    child: Text(
                      'Keluar',
                      style: AppTypography.jakarta(
                        size: 14,
                        weight: FontWeight.w700,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Kizen v1.0.0 (MVP)',
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
    );
  }

  Widget _eyebrow(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 22, 6, 8),
    child: Text(text.toUpperCase(), style: AppTypography.eyebrow),
  );

  Widget _card(List<Widget> children) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(children: children),
  );

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

  /// Sync manual. Firestore sendiri sudah live-sync terus-menerus (lihat
  /// docs/DATABASE.md) — "sync" sungguhan yang bisa dikerjakan tombol ini
  /// cuma dua hal: (1) sentuh dokumen profil (`lastSyncAt`, lewat
  /// [SyncService] yang sama dipakai saat login), (2) cek chapter baru
  /// sungguhan untuk semua komik Library dari sumber asli (sama seperti
  /// tombol refresh di tab Updates) — itu satu-satunya "tarik data baru
  /// dari luar" yang relevan di arsitektur ini.
  Future<void> _runSync(BuildContext context, WidgetRef ref) async {
    AppToast.show(context, 'Menyinkronkan data…');
    final results = await Future.wait([
      ref.read(updatesProvider.notifier).refresh(),
      ref.read(syncServiceProvider).syncAll(),
    ]);
    if (!context.mounted) return;
    final result = results[0] as UpdateCheckResult;
    AppToast.show(
      context,
      result.checked == 0
          ? 'Sinkronisasi selesai'
          : 'Sinkronisasi selesai · ${result.updated} komik ada chapter baru',
    );
  }

  Future<void> _checkUpdates(BuildContext context, WidgetRef ref) async {
    AppToast.show(context, 'Memeriksa chapter baru…');
    final result = await ref.read(updatesProvider.notifier).refresh();
    if (!context.mounted) return;
    AppToast.show(
      context,
      result.checked == 0
          ? 'Belum ada komik sumber asli di Library'
          : '${result.updated} komik ada chapter baru'
                '${result.failed > 0 ? ' · ${result.failed} gagal dicek' : ''}',
    );
  }

  Future<void> _checkExtensionRuntime(BuildContext context) async {
    AppToast.show(context, 'Mengecek runtime extension…');
    try {
      const bridge = ExtensionRuntimeBridge();
      final info = await bridge.runtimeInfo();
      final packages = await bridge.listInstalledExtensions();
      if (!context.mounted) return;
      final loader = info.capabilities.apkClassLoading
          ? 'loader APK aktif'
          : 'loader APK belum aktif';
      AppToast.show(
        context,
        '${info.platform} runtime aktif · ${packages.length} APK · $loader',
      );
      if (!info.capabilities.apkClassLoading || packages.isEmpty) return;

      final target = packages.firstWhere(
        (extension) => extension.packageName.toLowerCase().contains('.komiku'),
        orElse: () => packages.first,
      );
      final source = await bridge
          .inspectExtension(target.packageName)
          .timeout(const Duration(seconds: 8));
      if (!context.mounted) return;
      AppToast.show(context, 'Loaded ${source.name} · ${source.baseUrl}');

      final page = await bridge
          .fetchPopularFromExtension(target.packageName)
          .timeout(const Duration(seconds: 15));
      if (!context.mounted) return;
      AppToast.show(
        context,
        'Extension fetch OK · ${page.mangas.length} judul',
      );
    } catch (_) {
      if (context.mounted) {
        AppToast.show(context, 'Runtime extension belum bisa diakses');
      }
    }
  }

  Future<void> _clearHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'Bersihkan history?',
      message: 'Riwayat baca akan dikosongkan, tapi Library tetap aman.',
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(historyProvider.notifier).clear();
    if (context.mounted) AppToast.show(context, 'History dibersihkan');
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'Keluar dari akun?',
      message:
          'Kamu perlu masuk kembali dengan Google untuk mengakses Library '
          'dan data yang tersinkron.',
      confirmLabel: 'Keluar',
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(authControllerProvider.notifier).signOut();
    } catch (_) {
      if (context.mounted) AppToast.show(context, 'Gagal keluar dari akun');
      return;
    }
    ref
      ..invalidate(libraryProvider)
      ..invalidate(collectionsProvider)
      ..invalidate(bookmarksProvider)
      ..invalidate(historyProvider)
      ..invalidate(updatesProvider)
      ..invalidate(sourcesProvider)
      ..invalidate(repositoriesProvider)
      ..invalidate(activeLangsProvider);
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}
