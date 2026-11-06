import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/vpn_state.dart';

/// Layar Kizen VPN & Anti-Blokir — Akses bebas komik yang diblokir ISP di Indonesia.
class VpnScreen extends ConsumerStatefulWidget {
  const VpnScreen({super.key});

  @override
  ConsumerState<VpnScreen> createState() => _VpnScreenState();
}

class _VpnScreenState extends ConsumerState<VpnScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vpn = ref.watch(vpnProvider);
    final notifier = ref.read(vpnProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Row(
                children: [
                  Material(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(12),
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          AppIcons.back,
                          size: 20,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kizen VPN',
                          style: AppTypography.jakarta(
                            size: 19,
                            weight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Anti-Blokir & Akses Bebas Komik',
                          style: AppTypography.jakarta(
                            size: 12,
                            weight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: vpn.isEnabled
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: vpn.isEnabled
                            ? const Color(0xFF10B981).withValues(alpha: 0.4)
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: vpn.isEnabled
                                ? const Color(0xFF10B981)
                                : AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          vpn.isEnabled ? 'AKTIF' : 'MATI',
                          style: AppTypography.jakarta(
                            size: 11,
                            weight: FontWeight.w800,
                            color: vpn.isEnabled
                                ? const Color(0xFF10B981)
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 40),
                children: [
                  // Hero Interactive Power / VPN Card
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 26,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: vpn.isEnabled
                            ? [
                                const Color(0xFF132A22),
                                AppColors.surface,
                              ]
                            : [
                                AppColors.surfaceAlt,
                                AppColors.surface,
                              ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: vpn.isEnabled
                            ? const Color(0xFF10B981).withValues(alpha: 0.35)
                            : AppColors.border,
                        width: 1.5,
                      ),
                      boxShadow: [
                        if (vpn.isEnabled)
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            blurRadius: 28,
                            offset: const Offset(0, 8),
                          )
                        else
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: Column(
                      children: [
                        ScaleTransition(
                          scale: vpn.isEnabled
                              ? _pulseAnimation
                              : const AlwaysStoppedAnimation(1.0),
                          child: GestureDetector(
                            onTap: vpn.isConnecting
                                ? null
                                : () => notifier.toggle(),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 136,
                              height: 136,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: vpn.isEnabled
                                      ? [
                                          const Color(0xFF10B981),
                                          const Color(0xFF047857),
                                        ]
                                      : [
                                          const Color(0xFF2B3342),
                                          const Color(0xFF1E2430),
                                        ],
                                ),
                                boxShadow: [
                                  if (vpn.isEnabled)
                                    BoxShadow(
                                      color: const Color(0xFF10B981)
                                          .withValues(alpha: 0.45),
                                      blurRadius: 36,
                                      spreadRadius: 4,
                                      offset: const Offset(0, 8),
                                    )
                                  else
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.35),
                                      blurRadius: 14,
                                      offset: const Offset(0, 4),
                                    ),
                                ],
                                border: Border.all(
                                  color: vpn.isEnabled
                                      ? Colors.white.withValues(alpha: 0.35)
                                      : AppColors.borderStrong,
                                  width: 3.5,
                                ),
                              ),
                              child: Center(
                                child: vpn.isConnecting
                                    ? const AppSpinner(
                                        size: 38,
                                        strokeWidth: 3.5,
                                      )
                                    : Icon(
                                        LucideIcons.power,
                                        size: 52,
                                        color: vpn.isEnabled
                                            ? Colors.white
                                            : AppColors.textMuted,
                                      ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Status Badge Pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: vpn.isEnabled
                                ? const Color(0xFF10B981).withValues(alpha: 0.18)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: vpn.isEnabled
                                  ? const Color(0xFF10B981).withValues(alpha: 0.5)
                                  : AppColors.border,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                vpn.isEnabled
                                    ? LucideIcons.shieldCheck
                                    : LucideIcons.shieldAlert,
                                size: 14,
                                color: vpn.isEnabled
                                    ? const Color(0xFF10B981)
                                    : AppColors.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                vpn.isEnabled
                                    ? 'TERHUBUNG (AMAN & BEBAS BLOKIR)'
                                    : 'TERPUTUS (STANDAR)',
                                style: AppTypography.jakarta(
                                  size: 11.5,
                                  weight: FontWeight.w800,
                                  color: vpn.isEnabled
                                      ? const Color(0xFF10B981)
                                      : AppColors.textMuted,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (vpn.isEnabled) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                LucideIcons.zap,
                                size: 13,
                                color: Color(0xFF10B981),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Latensi Ping: ${vpn.pingMs} ms',
                                style: AppTypography.jakarta(
                                  size: 12,
                                  weight: FontWeight.w700,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'DNS Wire-Format DoH',
                                style: AppTypography.jakarta(
                                  size: 12,
                                  weight: FontWeight.w500,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 12),
                        Text(
                          vpn.isEnabled
                              ? 'Seluruh trafik DNS web komik dan galeri manga dialihkan melalui terowongan terenkripsi tanpa blokir Internet Positif.'
                              : 'Tekan tombol power di atas untuk menyalakan proteksi anti-blokir Kizen langsung di dalam aplikasi.',
                          textAlign: TextAlign.center,
                          style: AppTypography.jakarta(
                            size: 12,
                            weight: FontWeight.w400,
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Server Selection
                  _eyebrow('Lokasi Server VPN & Terowongan'),
                  _card([
                    for (final p in VpnProvider.values)
                      _serverOption(
                        provider: p,
                        title: p.label,
                        subtitle: switch (p) {
                          VpnProvider.hongkong =>
                            'Server Hong Kong (Bypass cepat galeri komik Asia)',
                          VpnProvider.cloudflare =>
                            'Server Singapura (Cloudflare Anycast - Latensi terendah)',
                          VpnProvider.adguard =>
                            'Server AdGuard (Proteksi iklan agresif & malware)',
                          VpnProvider.google =>
                            'Server Global (Google Public Anycast)',
                        },
                        selected: vpn.provider == p,
                        onTap: () => _handleSelectProvider(context, vpn, notifier, p),
                        showDivider: p != VpnProvider.values.last,
                      ),
                  ]),

                  // Pintasan Sistem Android (Hanya Pengaturan VPN Sistem)
                  _eyebrow('Pintasan Sistem'),
                  _card([
                    _menuRow(
                      icon: LucideIcons.settings2,
                      label: 'Pengaturan VPN Sistem HP',
                      subtitle: 'Buka konfigurasi VPN bawaan Android OS',
                      trailing: const Icon(
                        AppIcons.forward,
                        size: 16,
                        color: AppColors.textFaint,
                      ),
                      onTap: () => notifier.openSystemVpnSettings(),
                      showDivider: false,
                    ),
                  ]),

                  // Info Keamanan
                  _eyebrow('Fitur & Keamanan Kizen VPN'),
                  _card([
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _featureItem(
                            icon: LucideIcons.layers,
                            title: 'Terpasang di Dalam Aplikasi (Built-in)',
                            desc: 'Tidak perlu download aplikasi VPN tambahan dari Play Store atau bolak-balik ganti aplikasi.',
                          ),
                          const Divider(height: 20, color: AppColors.border),
                          _featureItem(
                            icon: LucideIcons.shieldCheck,
                            title: 'Bypass DNS Hijacking Telkom/ISP',
                            desc: 'Mengenkripsi query DNS port 53 langsung ke port 443 HTTPS dengan enkripsi TLS.',
                          ),
                          const Divider(height: 20, color: AppColors.border),
                          _featureItem(
                            icon: LucideIcons.eyeOff,
                            title: 'Zero Activity Log & Privasi Terjaga',
                            desc: 'Riwayat komik kamu tidak pernah dicatat atau dibagikan ke pihak ketiga mana pun.',
                          ),
                        ],
                      ),
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

  Future<void> _handleSelectProvider(
    BuildContext context,
    VpnState vpn,
    VpnNotifier notifier,
    VpnProvider target,
  ) async {
    if (vpn.isConnecting) return;

    if (vpn.provider == target) {
      AppToast.show(context, 'Server ${target.label} sedang aktif digunakan');
      return;
    }

    if (vpn.isEnabled) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.border),
          ),
          title: Row(
            children: [
              const Icon(
                LucideIcons.arrowLeftRight,
                color: AppColors.accent,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'Ganti Server VPN?',
                style: AppTypography.jakarta(size: 16, weight: FontWeight.w700),
              ),
            ],
          ),
          content: Text(
            'Koneksi VPN saat ini sedang aktif di:\n• ${vpn.provider.label}\n\nApakah kamu ingin memindahkan koneksi VPN ke:\n• ${target.label}?',
            style: AppTypography.jakarta(
              size: 13,
              weight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Batal',
                style: AppTypography.jakarta(
                  size: 13,
                  weight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Pindahkan Server',
                style: AppTypography.jakarta(
                  size: 13,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );

      if (confirm != true || !context.mounted) return;

      AppToast.show(
        context,
        'Mengalihkan koneksi ke ${target.label}…',
        icon: LucideIcons.refreshCw,
        iconColor: AppColors.accent,
      );

      await notifier.setProvider(target);

      if (!context.mounted) return;
      final currentVpn = ref.read(vpnProvider);
      AppToast.show(
        context,
        'Terhubung ke ${target.label} (${currentVpn.pingMs} ms)',
      );
    } else {
      await notifier.setProvider(target);
      if (!context.mounted) return;
      AppToast.show(
        context,
        'Server ${target.label} dipilih · Aktifkan VPN untuk mulai terhubung',
      );
    }
  }

  Widget _serverOption({
    required VpnProvider provider,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    final flag = switch (provider) {
      VpnProvider.hongkong => '🇭🇰',
      VpnProvider.cloudflare => '🇸🇬',
      VpnProvider.adguard => '🛡️',
      VpnProvider.google => '🌐',
    };

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Text(flag, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.jakarta(
                          size: 13.5,
                          weight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTypography.jakarta(
                          size: 11.5,
                          weight: FontWeight.w400,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected ? LucideIcons.circleDot : LucideIcons.circle,
                  size: 20,
                  color: selected ? const Color(0xFF10B981) : AppColors.textFaint,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 52, color: AppColors.border),
      ],
    );
  }

  Widget _menuRow({
    required IconData icon,
    required String label,
    String? subtitle,
    required Widget trailing,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.accentText),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTypography.jakarta(
                          size: 13.5,
                          weight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppTypography.jakarta(
                            size: 11.5,
                            weight: FontWeight.w400,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                trailing,
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 48, color: AppColors.border),
      ],
    );
  }

  Widget _featureItem({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF10B981)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.jakarta(
                  size: 13,
                  weight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: AppTypography.jakarta(
                  size: 11.5,
                  weight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
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
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: children),
      );
}
