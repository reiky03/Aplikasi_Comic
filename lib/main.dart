import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';

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
      // Placeholder — diganti alur Onboarding (03) setelah shared
      // components (15) dibangun.
      home: const _PlaceholderHome(),
    );
  }
}

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(AppDimens.radiusFab),
              ),
              child: const Icon(
                AppIcons.library,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text('My Comic', style: AppTypography.appName),
            const SizedBox(height: 6),
            Text('Design system siap — layar menyusul.',
                style: AppTypography.body),
          ],
        ),
      ),
    );
  }
}
