import 'package:flutter/material.dart';

class AppSettingsController extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;
  bool compactMode = false;

  void setThemeMode(ThemeMode value) {
    themeMode = value;
    notifyListeners();
  }

  void setCompactMode(bool value) {
    compactMode = value;
    notifyListeners();
  }
}
