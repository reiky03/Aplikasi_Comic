import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../library/library_screen.dart';

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
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(activeTabProvider);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: tab.index,
              children: const [
                LibraryScreen(),
                _PlaceholderTab(title: 'Updates'), // TODO(05)
                _PlaceholderTab(title: 'History'), // TODO(06)
                _PlaceholderTab(title: 'Jelajahi'), // TODO(07)
                _PlaceholderTab(title: 'Setelan'), // TODO(14)
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
        ],
      ),
    );
  }
}

/// Placeholder tab yang belum dibangun — diganti per file spek.
class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Align(
          alignment: Alignment.topLeft,
          child: Text(title, style: AppTypography.screenTitle),
        ),
      ),
    );
  }
}
