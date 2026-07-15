import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/updates_state.dart';

/// Tab Updates — spek 05: feed chapter baru per tanggal + refresh.
class UpdatesScreen extends ConsumerStatefulWidget {
  const UpdatesScreen({super.key});

  @override
  ConsumerState<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends ConsumerState<UpdatesScreen> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await ref.read(updatesProvider.notifier).refresh();
    if (!mounted) return;
    setState(() => _refreshing = false);
    AppToast.show(context, 'Updates diperbarui — memeriksa chapter baru');
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(updatesProvider);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text('Updates', style: AppTypography.screenTitle),
                ),
                if (_refreshing)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const AppSpinner(
                      size: 17,
                      strokeWidth: 2,
                      color: AppColors.menuIcon,
                    ),
                  )
                else
                  AppHeaderIconButton(
                    icon: LucideIcons.rotateCw,
                    onTap: _refresh,
                  ),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty ? _buildEmptyState() : _buildFeed(entries),
          ),
        ],
      ),
    );
  }

  Widget _buildFeed(List<UpdateEntry> entries) {
    final children = <Widget>[];
    String? currentGroup;
    for (final entry in entries) {
      if (entry.dateGroup != currentGroup) {
        currentGroup = entry.dateGroup;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Text(
              entry.dateGroup.toUpperCase(),
              style: AppTypography.jakarta(
                size: 12,
                weight: FontWeight.w800,
                letterSpacing: 0.6,
                color: AppColors.textMuted,
              ),
            ),
          ),
        );
      }
      children.add(_UpdateRow(entry: entry, onTap: () => _openDetail(entry)));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
      children: children,
    );
  }

  Widget _buildEmptyState() {
    return const AppEmptyState(
      icon: Icon(AppIcons.updates),
      title: 'Belum ada update terbaru',
      description: TextSpan(
        text: 'Chapter baru dari komik di library-mu akan muncul di sini.',
      ),
    );
  }

  void _openDetail(UpdateEntry entry) {
    // TODO(12): buka ComicDetailScreen (openedFrom: 'updates').
    AppToast.show(context, 'Comic Detail menyusul (spek 12)');
  }
}

class _UpdateRow extends StatelessWidget {
  const _UpdateRow({required this.entry, required this.onTap});

  final UpdateEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      highlightColor: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 58,
              decoration: BoxDecoration(
                gradient: comicCover(entry.hue),
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Text(
                entry.initial,
                style: AppTypography.jakarta(
                  size: 20,
                  weight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.16),
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppTypography.jakarta(size: 14, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    entry.chLabel,
                    style: AppTypography.jakarta(
                      size: 12.5,
                      weight: FontWeight.w600,
                      color: AppColors.accentText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.src,
                    style: AppTypography.jakarta(
                      size: 11,
                      weight: FontWeight.w400,
                      color: AppColors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              entry.time,
              style: AppTypography.jakarta(
                size: 11,
                weight: FontWeight.w400,
                color: AppColors.textFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
