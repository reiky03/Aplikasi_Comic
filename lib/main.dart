import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'data/source_session_store.dart';
import 'data/vpn_state.dart';
import 'features/auth/auth_repository.dart';
import 'features/onboarding/splash_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Perbesar batas cache bitmap Flutter agar chapter webtoon panjang (puluhan strip
  // resolusi tinggi) tidak terus-menerus di-evict dan di-decode ulang saat discroll.
  PaintingBinding.instance.imageCache.maximumSize = 2000;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 512 * 1024 * 1024; // 512 MB
  await SourceSessionStore.initialize();
  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemOverlayStyle);
  // FAKE_AUTH (web preview di sandbox) tidak butuh Firebase asli — lewati
  // supaya tidak gagal karena web/index.html belum punya script Firebase SDK.
  if (!kUseFakeAuth) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  runApp(const ProviderScope(child: KizenApp()));
}

class KizenApp extends ConsumerStatefulWidget {
  const KizenApp({super.key});

  @override
  ConsumerState<KizenApp> createState() => _KizenAppState();
}

class _KizenAppState extends ConsumerState<KizenApp> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        // Saat aplikasi kembali dibuka atau beralih ke foreground,
        // sinkronkan status VPN dengan service native (misal dimatikan dari notifikasi)
        ref.read(vpnProvider.notifier).refreshStatus();
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kizen',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const SplashScreen(),
    );
  }
}
