import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'data/source_session_store.dart';
import 'features/auth/auth_repository.dart';
import 'features/onboarding/splash_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

class KizenApp extends StatefulWidget {
  const KizenApp({super.key});

  @override
  State<KizenApp> createState() => _KizenAppState();
}

class _KizenAppState extends State<KizenApp> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onDetach: () {
        // Saat aplikasi ditutup (detached), pastikan VPN dimatikan agar tidak
        // terus menguras baterai di latar belakang
        const MethodChannel('kizen/extension_runtime').invokeMethod<void>(
          'setVpnEnabled',
          {'enabled': false, 'provider': 'cloudflare'},
        );
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
