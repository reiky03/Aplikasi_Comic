import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/widgets.dart';
import 'models.dart';
import '../features/browse/repo_browse_tab.dart';
import 'extension_runtime.dart';
import 'repository_state.dart';
import 'sources_state.dart';

/// Helper terpusat untuk alur pembaruan ekstensi Tachiyomi/Keiyoushi.
/// Menangani pencegahan bentrok signature (INSTALL_FAILED_UPDATE_INCOMPATIBLE)
/// saat ekstensi lama yang di-sign oleh official Tachiyomi ingin diperbarui
/// ke versi Keiyoushi.
abstract final class ExtensionUpdateHelper {
  /// Buka sheet opsi pembaruan ekstensi dengan penjelasan signature conflict.
  static Future<void> showUpdateSheet(
    BuildContext context, {
    required WidgetRef ref,
    required String name,
    required String packageName,
    required String apkUrl,
    required String fileName,
    String? newVersion,
    int? hue,
    VoidCallback? onInstalled,
  }) async {
    await showAppSheet<void>(
      context,
      menuStyle: true,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ContextMenuPreview(
            cover: comicCover(hue ?? 330),
            title: name,
            subtitle: newVersion == null
                ? 'Pembaruan tersedia'
                : 'Pembaruan ke v$newVersion',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningAlt.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warningAlt.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    LucideIcons.info,
                    size: 16,
                    color: AppColors.warningAlt,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Jika sebelumnya terpasang dari Tachiyomi lama, Android mewajibkan pencopotan versi lama terlebih dahulu agar tidak bentrok signature. Data favorit & histori tetap aman.',
                      style: AppTypography.jakarta(
                        size: 11.5,
                        weight: FontWeight.w500,
                        height: 1.45,
                        color: AppColors.warningAlt,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AppSheetMenuRow(
            icon: LucideIcons.trash2,
            iconColor: AppColors.warningAlt,
            label: 'Copot Versi Lama & Pasang Otomatis',
            onTap: () {
              Navigator.pop(sheetContext);
              uninstallAndReinstall(
                context,
                ref: ref,
                name: name,
                packageName: packageName,
                apkUrl: apkUrl,
                fileName: fileName,
                onInstalled: onInstalled,
              );
            },
          ),
          AppSheetMenuRow(
            icon: AppIcons.refresh,
            iconColor: AppColors.accent,
            label: 'Coba Perbarui Langsung',
            onTap: () {
              Navigator.pop(sheetContext);
              installDirect(
                context,
                ref: ref,
                apkUrl: apkUrl,
                fileName: fileName,
                onInstalled: onInstalled,
              );
            },
          ),
          AppSheetMenuRow(
            icon: AppIcons.delete,
            label: 'Hapus instal extension',
            destructive: true,
            onTap: () {
              Navigator.pop(sheetContext);
              uninstall(context, packageName: packageName);
            },
          ),
        ],
      ),
    );
  }

  /// Pasang APK langsung via PackageInstaller native.
  static Future<void> installDirect(
    BuildContext context, {
    required WidgetRef ref,
    required String apkUrl,
    required String fileName,
    VoidCallback? onInstalled,
  }) async {
    try {
      AppToast.show(context, 'Membuka installer ekstensi...');
      await const ExtensionRuntimeBridge().installExtensionApk(
        apkUrl: apkUrl,
        fileName: fileName,
      );
      if (!context.mounted) return;
      ref.invalidate(installedExtensionPackagesProvider);
      ref
          .read(sourcesProvider.notifier)
          .syncWithRepositories(ref.read(repositoriesProvider));
      onInstalled?.call();
    } catch (e) {
      if (!context.mounted) return;
      AppToast.show(context, 'Gagal membuka installer: $e');
    }
  }

  /// Alur copot versi lama lalu pasang ulang versi baru secara otomatis.
  /// Menjamin tidak terjadi race condition: APK baru diunduh terlebih dahulu,
  /// dialog uninstall dibuka, lalu memantau hingga paket lama benar-benar
  /// terhapus sebelum membuka installer APK baru.
  static Future<void> uninstallAndReinstall(
    BuildContext context, {
    required WidgetRef ref,
    required String name,
    required String packageName,
    required String apkUrl,
    required String fileName,
    VoidCallback? onInstalled,
  }) async {
    try {
      AppToast.show(context, 'Mengunduh APK pembaruan $name...');
      // 1. Unduh APK terlebih dahulu ke cache agar siap instan
      await const ExtensionRuntimeBridge().prepareExtensionApk(
        apkUrl: apkUrl,
        fileName: fileName,
      );

      if (!context.mounted) return;
      AppToast.show(
        context,
        'Tekan "OK" pada dialog pencopotan versi lama di layar HP',
      );

      // 2. Buka dialog pencopotan OS
      await const ExtensionRuntimeBridge().uninstallExtensionPackage(
        packageName,
      );

      if (!context.mounted) return;

      // 3. Pantau secara reaktif hingga paket lama terhapus (maks 60 detik)
      final deadline = DateTime.now().add(const Duration(seconds: 60));
      var uninstalled = false;

      while (DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (!context.mounted) return;

        final currentList = await const ExtensionRuntimeBridge()
            .listInstalledExtensions();
        final stillInstalled = currentList.any(
          (pkg) => pkg.packageName == packageName,
        );

        if (!stillInstalled) {
          uninstalled = true;
          break;
        }
      }

      if (!uninstalled) {
        if (!context.mounted) return;
        AppToast.show(
          context,
          'Pencopotan versi lama dibatalkan. Ekstensi tetap versi lama.',
        );
        return;
      }

      // 4. Paket lama sudah berhasil dicopot! Buka installer versi baru
      if (!context.mounted) return;
      AppToast.show(
        context,
        'Versi lama dicopot. Membuka installer versi baru...',
      );

      await const ExtensionRuntimeBridge().installExtensionApk(
        apkUrl: apkUrl,
        fileName: fileName,
      );

      if (!context.mounted) return;
      ref.invalidate(installedExtensionPackagesProvider);
      ref
          .read(sourcesProvider.notifier)
          .syncWithRepositories(ref.read(repositoriesProvider));
      onInstalled?.call();
    } catch (e) {
      if (!context.mounted) return;
      AppToast.show(context, 'Gagal copot dan pasang ulang: $e');
    }
  }

  /// Buka dialog uninstaller bawaan OS untuk package.
  static Future<void> uninstall(
    BuildContext context, {
    required String packageName,
  }) async {
    try {
      await const ExtensionRuntimeBridge().uninstallExtensionPackage(
        packageName,
      );
      if (!context.mounted) return;
      AppToast.show(context, 'Dialog hapus instal dibuka');
    } catch (e) {
      if (!context.mounted) return;
      AppToast.show(context, 'Gagal membuka hapus instal: $e');
    }
  }
}
