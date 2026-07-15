import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Toast — spek 15: muncul di bawah (bottom 120, di atas nav/FAB),
/// bg #26262f, radius 14, ikon lingkaran hijau + centang, auto-dismiss 2.4s.
/// Toast baru menggantikan toast yang masih tampil (seperti prototipe).
abstract final class AppToast {
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(BuildContext context, String message) {
    _timer?.cancel();
    _entry?.remove();

    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(builder: (_) => _ToastView(message: message));
    _entry = entry;
    overlay.insert(entry);

    _timer = Timer(AppMotion.toastVisible, () {
      _entry?.remove();
      _entry = null;
    });
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({required this.message});

  final String message;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: Curves.ease);
    return Positioned(
      left: 20,
      right: 20,
      bottom: 120,
      child: IgnorePointer(
        // Material transparan: tanpa ini, Text di Overlay dirender
        // dengan underline kuning default TextStyle.
        child: Material(
          type: MaterialType.transparency,
          child: FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.15),
                end: Offset.zero,
              ).animate(curved),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: AppColors.toastBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.sheetTopBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xB3000000),
                      offset: Offset(0, 12),
                      blurRadius: 30,
                      spreadRadius: -10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        AppIcons.downloaded,
                        size: 13,
                        color: AppColors.bg,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: AppTypography.jakarta(
                          size: 13.5,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
