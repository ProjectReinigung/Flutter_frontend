import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/user.dart';
import '../config/app_config.dart';
import '../network/api_client.dart';
import '../network/services.dart';
import '../storage/token_storage.dart';

class AuthController extends ChangeNotifier {
  AuthController({required this.tokenStorage, required this.apiClient});

  final TokenStorage tokenStorage;
  final ApiClient apiClient;

  AppUser? user;
  String backendUrl = AppConfig.defaultBackendUrl;
  bool loading = false;

  bool get isAuthenticated => user != null;

  Future<void> restore() async {
    backendUrl = await tokenStorage.readBackendUrl();
    final token = await tokenStorage.readToken();
    if (token == null) return;
    if (_isExpired(token)) {
      await tokenStorage.clearToken();
      return;
    }
    try {
      user = await UsersApi(apiClient).me();
    } catch (_) {
      await tokenStorage.clearToken();
    }
  }

  Future<void> login({
    required String backend,
    required String username,
    required String password,
    String? keycloakBase,
    String? realm,
    String? clientId,
  }) async {
    loading = true;
    notifyListeners();
    try {
      final normalizedKeycloakBase =
          (keycloakBase ?? AppConfig.defaultKeycloakUrl).replaceAll(
            RegExp(r'/$'),
            '',
          );
      await tokenStorage.saveBackendUrl(backend);
      backendUrl = backend.replaceAll(RegExp(r'/$'), '');
      final tokenUri = Uri.parse(
        '$normalizedKeycloakBase/realms/${realm ?? AppConfig.keycloakRealm}/protocol/openid-connect/token',
      );
      final response = await http.post(
        tokenUri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'password',
          'client_id': clientId ?? AppConfig.keycloakClientId,
          'username': username,
          'password': password,
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          response.body.isEmpty
              ? 'Sign-in failed. Check your username and password.'
              : response.body,
          response.statusCode,
        );
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      await tokenStorage.saveToken(body['access_token'] as String);
      user = await UsersApi(apiClient).me();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> completePasswordChange({
    required String backend,
    required String username,
    required String currentPassword,
    required String newPassword,
  }) async {
    loading = true;
    notifyListeners();
    try {
      await tokenStorage.saveBackendUrl(backend);
      backendUrl = backend.replaceAll(RegExp(r'/$'), '');
      final response = await http.post(
        Uri.parse('$backendUrl/api/auth/complete-password-change'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          response.body.isEmpty
              ? 'Password change failed. Check the temporary password and try again.'
              : response.body,
          response.statusCode,
        );
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUser() async {
    user = await UsersApi(apiClient).me();
    notifyListeners();
  }

  Future<void> logout() async {
    await tokenStorage.clearToken();
    user = null;
    notifyListeners();
  }

  bool _isExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return false;
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final exp = (jsonDecode(payload) as Map<String, dynamic>)['exp'];
      if (exp is! int) return false;
      return DateTime.now().isAfter(
        DateTime.fromMillisecondsSinceEpoch(exp * 1000),
      );
    } catch (_) {
      return false;
    }
  }
}
