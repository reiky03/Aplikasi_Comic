import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/demo_state.dart';
import '../sync/sync_service.dart';
import '../auth/auth_repository.dart';
import '../onboarding/login_screen.dart';
import '../reader/reader_settings_sheet.dart';

/// Tab Setelan — spek 14.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider);
    final themeLabel = ref.watch(themeModeLabelProvider);

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
                            colors: [Color(0xFF8A6BFF), Color(0xFF5B3EDE)],
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
                                  size: 15, weight: FontWeight.w700),
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
                      themeLabel,
                      style: AppTypography.jakarta(
                        size: 13,
                        weight: FontWeight.w400,
                        color: AppColors.textMuted,
                      ),
                    ),
                    onTap: () => _openThemeSheet(context, ref),
                  ),
                  _menuRow(
                    icon: LucideIcons.alignLeft,
                    label: 'Pengaturan Reader',
                    trailing: const Icon(AppIcons.forward,
                        size: 16, color: AppColors.textFaint),
                    onTap: () => showReaderSettingsSheet(context),
                  ),
                  _menuRow(
                    icon: LucideIcons.rotateCw,
                    label: 'Sinkronisasi & Cadangan',
                    trailing: const Icon(AppIcons.forward,
                        size: 16, color: AppColors.textFaint),
                    onTap: () => _runSync(context),
                    showDivider: false,
                  ),
                ]),
                _eyebrow('Demo state (prototype)'),
                _card([
                  _toggleRow(context, ref, 'Library kosong',
                      demoLibEmptyProvider),
                  _toggleRow(context, ref, 'History kosong',
                      demoHistEmptyProvider),
                  _toggleRow(context, ref, 'Jelajahi kosong',
                      demoBrowseEmptyProvider),
                  _toggleRow(context, ref, 'Simulasi gagal sync saat login',
                      syncDebugFailProvider),
                  _toggleRow(context, ref, 'Repository kosong',
                      demoRepoEmptyProvider,
                      showDivider: false),
                ]),
                const SizedBox(height: 22),
                InkWell(
                  onTap: () => _signOut(context, ref),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0x14FF5C7A), // rgba(255,92,122,.08)
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: const Color(0x4DFF5C7A)), // .3
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
                  'My Comic v1.0.0 (MVP)',
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
        child: Text(
          text.toUpperCase(),
          style: AppTypography.eyebrow,
        ),
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
    required VoidCallback onTap,
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

  Widget _toggleRow(
    BuildContext context,
    WidgetRef ref,
    String label,
    NotifierProvider<dynamic, bool> provider, {
    bool showDivider = true,
  }) {
    final value = ref.watch(provider);
    void toggle() {
      final notifier = ref.read(provider.notifier);
      // DemoFlag & SyncDebugFail sama-sama expose toggle/set.
      if (notifier is DemoFlag) {
        notifier.toggle();
      } else if (notifier is SyncDebugFail) {
        notifier.set(!value);
      }
    }

    return InkWell(
      onTap: toggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: showDivider
            ? const BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: AppColors.sheetRowDivider)),
              )
            : null,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style:
                    AppTypography.jakarta(size: 13.5, weight: FontWeight.w600),
              ),
            ),
            AppPillSwitch(
              value: value,
              onChanged: (_) => toggle(),
              width: 44,
              height: 26,
            ),
          ],
        ),
      ),
    );
  }

  void _openThemeSheet(BuildContext context, WidgetRef ref) {
    showAppSheet<void>(
      context,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          final current = ref.watch(themeModeLabelProvider);
          void pick(String label) {
            ref.read(themeModeLabelProvider.notifier).set(label);
            Navigator.pop(sheetContext);
            AppToast.show(context, 'Tema: $label');
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppSheetTitle('Tema aplikasi'),
              AppSheetOptionRow(
                label: 'Gelap',
                selected: current == 'Gelap',
                showTopDivider: false,
                onTap: () => pick('Gelap'),
              ),
              AppSheetOptionRow(
                label: 'Terang',
                selected: current == 'Terang',
                onTap: () => pick('Terang'),
              ),
              AppSheetOptionRow(
                label: 'Ikuti sistem',
                selected: current == 'Ikuti sistem',
                onTap: () => pick('Ikuti sistem'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                child: Text(
                  'Prototype ini dark-first — mode Terang/Sistem tersedia di '
                  'versi final.',
                  style: AppTypography.jakarta(
                    size: 11,
                    weight: FontWeight.w400,
                    color: AppColors.textFaintest,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Sync manual — pola toast prototipe (1.4s).
  /// TODO(backend): panggil sync sungguhan.
  Future<void> _runSync(BuildContext context) async {
    AppToast.show(context, 'Menyinkronkan data…');
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!context.mounted) return;
    AppToast.show(context, 'Sinkronisasi selesai');
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authControllerProvider.notifier).signOut();
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}
