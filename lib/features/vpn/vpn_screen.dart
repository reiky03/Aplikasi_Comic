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
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  // Hero Power / VPN Button
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
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
                                width: 140,
                                height: 140,
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
                                            AppColors.surfaceAlt,
                                            AppColors.surface,
                                          ],
                                  ),
                                  boxShadow: [
                                    if (vpn.isEnabled)
                                      BoxShadow(
                                        color: const Color(0xFF10B981)
                                            .withValues(alpha: 0.4),
                                        blurRadius: 32,
                                        spreadRadius: 4,
                                        offset: const Offset(0, 8),
                                      )
                                    else
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                  ],
                                  border: Border.all(
                                    color: vpn.isEnabled
                                        ? Colors.white.withValues(alpha: 0.3)
                                        : AppColors.border,
                                    width: 3,
                                  ),
                                ),
                                child: Center(
                                  child: vpn.isConnecting
                                      ? const AppSpinner(
                                          size: 36,
                                          strokeWidth: 3,
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
                          const SizedBox(height: 18),
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: vpn.isEnabled
                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                  : AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: vpn.isEnabled
                                    ? const Color(0xFF10B981)
                                        .withValues(alpha: 0.4)
                                    : AppColors.border,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: vpn.isEnabled
                                        ? const Color(0xFF10B981)
                                        : AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  vpn.isEnabled
                                      ? 'TERHUBUNG (AMAN)'
                                      : 'TERPUTUS (STANDAR)',
                                  style: AppTypography.jakarta(
                                    size: 12,
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
                          const SizedBox(height: 8),
                          Text(
                            vpn.isEnabled
                                ? 'DNS Terenkripsi aktif — semua web komik bebas diakses tanpa blokir Internet Positif.'
                                : 'Tekan tombol di atas untuk mengaktifkan proteksi anti-blokir.',
                            textAlign: TextAlign.center,
                            style: AppTypography.jakarta(
                              size: 12,
                              weight: FontWeight.w400,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  _eyebrow('Server / Provider Terowongan'),
                  _card([
                    for (final p in VpnProvider.values)
                      _serverOption(
                        title: p.label,
                        subtitle: p == VpnProvider.hongkong
                            ? 'Server Hong Kong (Bypass cepat doujin & galeri Asia)'
                            : (p == VpnProvider.cloudflare
                                ? 'Rekomendasi (Ping tercepat & tembus semua komik)'
                                : (p == VpnProvider.adguard
                                    ? 'Proteksi iklan popup & malware web'
                                    : 'Alternatif global stabil')),
                        selected: vpn.provider == p,
                        onTap: () => notifier.setProvider(p),
                        showDivider: p != VpnProvider.values.last,
                      ),
                  ]),

                  _eyebrow('Diagnostik Jaringan Komik'),
                  Container(
                    margin: const EdgeInsets.only(bottom: 22),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  LucideIcons.gauge,
                                  size: 16,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Latensi Ping',
                                  style: AppTypography.jakarta(
                                    size: 13,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${vpn.pingMs} ms',
                                style: AppTypography.jakarta(
                                  size: 12,
                                  weight: FontWeight.w700,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: 12),
                        Text(
                          'STATUS AKSES WEB KOMIK',
                          style: AppTypography.eyebrow,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final entry in (vpn.testedHosts.isEmpty
                                ? {
                                    'Shinigami': true,
                                    'Komiku': true,
                                    'Komikindo': true,
                                    'Asura': true,
                                  }.entries
                                : vpn.testedHosts.entries))
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: (entry.value && vpn.isEnabled)
                                      ? const Color(0xFF10B981)
                                          .withValues(alpha: 0.12)
                                      : AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: (entry.value && vpn.isEnabled)
                                        ? const Color(0xFF10B981)
                                            .withValues(alpha: 0.3)
                                        : AppColors.border,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      (entry.value && vpn.isEnabled)
                                          ? LucideIcons.circleCheckBig
                                          : LucideIcons.circleAlert,
                                      size: 14,
                                      color: (entry.value && vpn.isEnabled)
                                          ? const Color(0xFF10B981)
                                          : AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${entry.key}: ${(entry.value && vpn.isEnabled) ? "Tembus" : "Standar"}',
                                      style: AppTypography.jakarta(
                                        size: 11.5,
                                        weight: FontWeight.w600,
                                        color: (entry.value && vpn.isEnabled)
                                            ? const Color(0xFF10B981)
                                            : AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 40,
                          child: OutlinedButton.icon(
                            onPressed: () => notifier.testConnection(),
                            icon: const Icon(LucideIcons.refreshCw, size: 14),
                            label: const Text('Uji Ulang Koneksi'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  _eyebrow('Pintasan Sistem Android'),
                  _card([
                    _menuRow(
                      icon: LucideIcons.shield,
                      label: 'Pengaturan VPN Sistem HP',
                      subtitle: 'Buka menu konfigurasi VPN bawaan Android',
                      trailing: const Icon(
                        AppIcons.forward,
                        size: 16,
                        color: AppColors.textFaint,
                      ),
                      onTap: () => notifier.openSystemVpnSettings(),
                    ),
                    _menuRow(
                      icon: LucideIcons.globe,
                      label: 'Private DNS Android (1-Tap)',
                      subtitle: 'Panduan set Private DNS: dns.cloudflare-dns.com',
                      trailing: const Icon(
                        AppIcons.forward,
                        size: 16,
                        color: AppColors.textFaint,
                      ),
                      onTap: () {
                        notifier.openPrivateDnsSettings();
                        AppToast.show(
                          context,
                          'Pilih Private DNS di HP kamu lalu isi: dns.cloudflare-dns.com',
                        );
                      },
                      showDivider: false,
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

  Widget _serverOption({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Icon(
                  selected
                      ? LucideIcons.circleDot
                      : LucideIcons.circle,
                  size: 18,
                  color: selected ? AppColors.accent : AppColors.textFaint,
                ),
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
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 48, color: AppColors.border),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
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
}
