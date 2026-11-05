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
class ExtensionUpdateHelper {
  const ExtensionUpdateHelper._();
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
                ? 'Pilihan ekstensi'
                : 'Tersedia pembaruan v$newVersion',
          ),
          AppSheetMenuRow(
            icon: AppIcons.refresh,
            iconColor: AppColors.accent,
            label: 'Perbarui Otomatis',
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
            icon: LucideIcons.download,
            label: 'Coba Timpa Langsung',
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
            label: 'Copot Ekstensi',
            destructive: true,
            onTap: () async {
              Navigator.pop(sheetContext);
              final confirmed = await showConfirmSheet(
                context,
                title: 'Copot Ekstensi?',
                message: 'Copot "$name" dari perangkat?',
                confirmLabel: 'Oke, Hapus',
              );
              if (!confirmed || !context.mounted) return;
              uninstall(context, ref: ref, packageName: packageName);
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
      AppToast.show(context, 'Mengunduh pembaruan...');
      // 1. Unduh APK terlebih dahulu ke cache agar siap instan
      await const ExtensionRuntimeBridge().prepareExtensionApk(
        apkUrl: apkUrl,
        fileName: fileName,
      );

      if (!context.mounted) return;
      AppToast.show(context, 'Membuka pencopotan...');

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
        AppToast.show(context, 'Pencopotan dibatalkan');
        return;
      }

      // 4. Paket lama sudah berhasil dicopot! Buka installer versi baru
      if (!context.mounted) return;
      AppToast.show(context, 'Memasang versi baru...');

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
      AppToast.show(context, 'Gagal memperbarui: $e');
    }
  }

  /// Buka dialog uninstaller bawaan OS untuk package dan pantau hingga selesai.
  static Future<void> uninstall(
    BuildContext context, {
    WidgetRef? ref,
    required String packageName,
  }) async {
    try {
      AppToast.show(context, 'Membuka pencopotan...');
      await const ExtensionRuntimeBridge().uninstallExtensionPackage(
        packageName,
      );
      if (!context.mounted) return;

      final deadline = DateTime.now().add(const Duration(seconds: 45));
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

      if (!context.mounted) return;
      if (uninstalled) {
        AppToast.show(context, 'Ekstensi berhasil dicopot');
        if (ref != null) {
          ref.invalidate(installedExtensionPackagesProvider);
          ref
              .read(sourcesProvider.notifier)
              .syncWithRepositories(ref.read(repositoriesProvider));
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      AppToast.show(context, 'Gagal mencopot: $e');
    }
  }
}
