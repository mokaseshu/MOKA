import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/splash_login_screen.dart';
import 'state/settings_controller.dart';
import 'utils/app_theme.dart';

class WalkQuestApp extends StatelessWidget {
  const WalkQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<SettingsController, ThemeMode>((s) => s.value.themeMode);
    return MaterialApp(
      title: 'WalkQuest 3D',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const SplashLoginScreen(),
    );
  }
}
