import 'package:flutter/material.dart';

import 'app.dart';
import 'core/auth/auth_controller.dart';
import 'core/network/api_client.dart';
import 'core/settings/app_settings_controller.dart';
import 'core/storage/token_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final tokenStorage = TokenStorage();
  final apiClient = ApiClient(tokenStorage: tokenStorage);
  final authController = AuthController(
    tokenStorage: tokenStorage,
    apiClient: apiClient,
  );
  apiClient.onUnauthorized = authController.logout;
  await authController.restore();
  runApp(
    CleaningManagerApp(
      authController: authController,
      settingsController: AppSettingsController(),
    ),
  );
}
