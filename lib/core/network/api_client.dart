import 'dart:convert';

import 'package:http/http.dart' as http;

import '../storage/token_storage.dart';

class ApiException implements Exception {
  const ApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({required this.tokenStorage, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final TokenStorage tokenStorage;
  final http.Client _http;
  Future<void> Function()? onUnauthorized;

  Future<Uri> _uri(String path) async {
    final base = await tokenStorage.readBackendUrl();
    return Uri.parse('$base$path');
  }

  Future<Map<String, String>> _headers() async {
    final token = await tokenStorage.readToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> get(String path) async =>
      _decode(await _http.get(await _uri(path), headers: await _headers()));

  Future<dynamic> post(String path, Object body) async {
    return _decode(
      await _http.post(
        await _uri(path),
        headers: await _headers(),
        body: jsonEncode(body),
      ),
    );
  }

  Future<dynamic> put(String path, [Object? body]) async {
    return _decode(
      await _http.put(
        await _uri(path),
        headers: await _headers(),
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<void> delete(String path) async {
    _decode(await _http.delete(await _uri(path), headers: await _headers()));
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode == 401) {
      onUnauthorized?.call();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.body.isEmpty
            ? 'Request failed (${response.statusCode}).'
            : response.body,
        response.statusCode,
      );
    }
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }
}
