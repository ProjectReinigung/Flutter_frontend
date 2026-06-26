import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

class TokenStorage {
  static const _tokenKey = 'auth_token';
  static const _backendUrlKey = 'backend_url';
  static const _secureStorage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock),
    wOptions: WindowsOptions(),
    lOptions: LinuxOptions(),
  );

  Future<String?> readToken() async {
    // Web cannot use OS keychains; shared_preferences maps to browser storage.
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    }
    return _secureStorage.read(key: _tokenKey);
  }

  Future<void> saveToken(String token) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      return;
    }
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  Future<void> clearToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      return;
    }
    await _secureStorage.delete(key: _tokenKey);
  }

  Future<String> readBackendUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_backendUrlKey) ?? AppConfig.defaultBackendUrl;
  }

  Future<void> saveBackendUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backendUrlKey, url.replaceAll(RegExp(r'/$'), ''));
  }
}
