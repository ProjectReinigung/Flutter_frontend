import 'package:cleaning_manager/app.dart';
import 'package:cleaning_manager/core/auth/auth_controller.dart';
import 'package:cleaning_manager/core/network/api_client.dart';
import 'package:cleaning_manager/core/settings/app_settings_controller.dart';
import 'package:cleaning_manager/core/storage/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows login screen by default', (tester) async {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    final storage = TokenStorage();
    final auth = AuthController(
      tokenStorage: storage,
      apiClient: ApiClient(tokenStorage: storage),
    );
    await tester.pumpWidget(
      CleaningManagerApp(
        authController: auth,
        settingsController: AppSettingsController(),
      ),
    );
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Username or email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(
      find.text('Use your company account to open Cleaning Manager.'),
      findsOneWidget,
    );
    expect(find.text('Developer connection settings'), findsNothing);
    expect(find.text('Backend URL'), findsNothing);
  });
}
