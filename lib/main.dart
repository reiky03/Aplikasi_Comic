import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'dev/components_preview.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemOverlayStyle);
  runApp(const ProviderScope(child: MyComicApp()));
}

class MyComicApp extends StatelessWidget {
  const MyComicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Comic',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      // Harness dev sementara untuk review shared components (15);
      // diganti alur Onboarding saat 03 dibangun.
      home: const ComponentsPreviewScreen(),
    );
  }
}

