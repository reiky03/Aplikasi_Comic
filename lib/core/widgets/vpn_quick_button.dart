import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/vpn_state.dart';
import '../theme/app_theme.dart';
import 'app_toast.dart';

/// Tombol Quick Toggle VPN Kizen untuk disematkan di Reader toolbar,
/// Header Halaman Sumber, Detail Komik, dan WebView.
///
/// Memungkinkan pengguna langsung menyalakan/mematikan VPN secara instan
/// saat sedang membaca komik atau membuka halaman yang terblokir, tanpa
/// harus bolak-balik keluar ke menu Pengaturan.
class KizenVpnQuickButton extends ConsumerWidget {
  const KizenVpnQuickButton({
    super.key,
    this.compact = true,
    this.onToggled,
  });

  /// Jika `true`, tombol berukuran kompak (kotak/lingkaran) cocok untuk App Bar.
  /// Jika `false`, berbentuk kapsul (pill) dengan label teks "VPN ON / OFF".
  final bool compact;

  /// Callback opsional yang dipanggil setelah VPN berhasil di-toggle
  /// (misalnya untuk auto-reload halaman atau chapter yang sempat gagal).
  final ValueChanged<bool>? onToggled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vpn = ref.watch(vpnProvider);
    final isEnabled = vpn.isEnabled;
    final isConnecting = vpn.isConnecting;

    final activeColor = const Color(0xFF10B981); // Emerald
    final inactiveColor = const Color(0xFFF59E0B); // Amber / Warning
    final baseColor = isEnabled ? activeColor : inactiveColor;

    return Semantics(
      label: isEnabled ? 'VPN Kizen Aktif' : 'VPN Kizen Nonaktif',
      button: true,
      child: Tooltip(
        message: isEnabled
            ? 'VPN Kizen: AKTIF (${vpn.provider.label.split(' ').first})\nKetuk untuk mematikan'
            : 'VPN Kizen: NONAKTIF\nKetuk untuk langsung aktifkan',
        child: InkWell(
          onTap: isConnecting
              ? null
              : () async {
                  final willEnable = !isEnabled;
                  await ref.read(vpnProvider.notifier).toggle();
                  if (context.mounted) {
                    AppToast.show(
                      context,
                      willEnable
                          ? '🛡️ VPN Kizen Aktif (${vpn.provider.label.split(' ').first})'
                          : 'VPN Kizen Dinonaktifkan',
                    );
                  }
                  onToggled?.call(willEnable);
                },
          borderRadius: BorderRadius.circular(compact ? 12 : 16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: compact ? 38 : 34,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 9 : 12,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: isEnabled
                  ? activeColor.withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(compact ? 12 : 16),
              border: Border.all(
                color: isEnabled
                    ? activeColor.withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.22),
                width: 1.2,
              ),
              boxShadow: isEnabled
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.25),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isConnecting)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(baseColor),
                    ),
                  )
                else
                  Icon(
                    isEnabled
                        ? LucideIcons.shieldCheck
                        : LucideIcons.shieldAlert,
                    size: compact ? 18 : 16,
                    color: baseColor,
                  ),
                if (!compact) ...[
                  const SizedBox(width: 6),
                  Text(
                    isEnabled ? 'VPN ON' : 'VPN OFF',
                    style: AppTypography.mono(
                      size: 11.5,
                      weight: FontWeight.w700,
                      color: baseColor,
                    ),
                  ),
                ] else ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: baseColor,
                      boxShadow: isEnabled
                          ? [
                              BoxShadow(
                                color: activeColor,
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
