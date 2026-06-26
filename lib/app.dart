import 'package:flutter/material.dart';

import 'core/auth/auth_controller.dart';
import 'core/router/app_router.dart';
import 'core/settings/app_settings_controller.dart';
import 'core/theme/app_theme.dart';

class CleaningManagerApp extends StatelessWidget {
  const CleaningManagerApp({
    super.key,
    required this.authController,
    required this.settingsController,
  });

  final AuthController authController;
  final AppSettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([authController, settingsController]),
      builder: (context, _) {
        return MaterialApp(
          title: 'Cleaning Manager',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: settingsController.themeMode,
          home: AppRouter(
            authController: authController,
            settingsController: settingsController,
          ),
        );
      },
    );
  }
}
