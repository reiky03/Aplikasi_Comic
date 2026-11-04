import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/app_fab.dart';
import '../../data/app_update_checker.dart';
import '../browse/browse_screen.dart';
import '../history/history_screen.dart';
import '../library/library_screen.dart';
import '../settings/about_screen.dart';
import '../settings/settings_screen.dart';
import '../updates/updates_screen.dart';

/// Tab yang sedang aktif di shell utama.
class ActiveTab extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.library;

  void set(AppTab tab) => state = tab;
}

final activeTabProvider = NotifierProvider<ActiveTab, AppTab>(ActiveTab.new);

/// Shell 5 tab dengan bottom nav persisten. Route pushed (Add Source,
/// Comic Detail, Reader, dst.) tampil full-screen di atas shell ini,
/// otomatis menutupi nav — sesuai spek 15.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  static bool _updateCheckedThisSession = false;
  Timer? _updateTimer;

  bool get _isTestEnv {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    if (!_isTestEnv && !_updateCheckedThisSession) {
      _updateCheckedThisSession = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) _checkUpdateSilently();
        });
      });
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkUpdateSilently() async {
    if (!mounted) return;
    try {
      final result = await checkForAppUpdate(currentVersion: kAppVersion);
      if (!mounted) return;
      if (result.hasUpdate) {
        await showAppUpdateModal(
          context,
          result: result,
          currentVersion: kAppVersion,
          onOpenUrl: (url) async {
            try {
              await launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              );
            } catch (_) {}
          },
        );
      }
    } catch (_) {
      // Pengecekan otomatis di background hening jika offline atau gagal
    }
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(activeTabProvider);
    final browseSubTab = ref.watch(browseSubTabProvider);
    final showFab =
        tab == AppTab.browse && browseSubTab == BrowseSubTab.own;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: tab.index,
              children: const [
                LibraryScreen(),
                UpdatesScreen(),
                HistoryScreen(),
                BrowseScreen(),
                SettingsScreen(),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: AppBottomNavBackdrop(
              child: AppBottomNav(
                active: tab,
                onSelect: (t) => ref.read(activeTabProvider.notifier).set(t),
              ),
            ),
          ),
          if (showFab)
            Positioned(
              right: AppDimens.fabRight,
              bottom: AppDimens.fabBottom,
              child: AppFab(onTap: () => openAddSource(context)),
            ),
        ],
      ),
    );
  }
}
