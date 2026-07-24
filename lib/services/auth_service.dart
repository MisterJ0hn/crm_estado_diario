import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// Error thrown for any login failure, with a message safe to show to the user.
class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Handles authentication against the CRM API and persists the session
/// (token + credentials) so the login screen only needs to be shown once.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final _storage = const FlutterSecureStorage();

  static const _keyToken = 'auth_token';
  static const _keyExpiresAt = 'auth_expires_at';
  static const _keyUsername = 'auth_username';
  static const _keyPassword = 'auth_password';

  /// Calls POST {baseUrl}/auth and stores the resulting token and the
  /// credentials used, so the session can be silently renewed later.
  Future<String> login(String username, String password) async {
    final baseUrl = await ApiConfig.getBaseUrl();
    final uri = Uri.parse('$baseUrl/auth');

    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw AuthException(
        'No se pudo conectar con el servidor. Verifica tu conexión o la URL de la API.',
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw AuthException('Usuario o contraseña incorrectos.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException('Error del servidor (${response.statusCode}).');
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw AuthException('Respuesta inválida del servidor.');
    }

    final token = data['token'] as String?;
    final expiresAt = data['expires_at'] as String?;
    if (token == null || token.isEmpty || expiresAt == null) {
      throw AuthException('Respuesta inválida del servidor.');
    }

    await _storage.write(key: _keyToken, value: token);
    await _storage.write(key: _keyExpiresAt, value: expiresAt);
    await _storage.write(key: _keyUsername, value: username);
    await _storage.write(key: _keyPassword, value: password);

    return token;
  }

  /// True if there is a still-valid stored token, or credentials that were
  /// successfully re-used to obtain a fresh one. Never throws: any storage
  /// or network failure is treated as "no session available".
  Future<bool> tryRestoreSession() async {
    try {
      final token = await _storage.read(key: _keyToken);
      final expiresAtRaw = await _storage.read(key: _keyExpiresAt);

      if (token != null && expiresAtRaw != null) {
        final expiresAt = _parseExpiresAt(expiresAtRaw);
        if (expiresAt != null && expiresAt.isAfter(DateTime.now())) {
          return true;
        }
      }

      final username = await _storage.read(key: _keyUsername);
      final password = await _storage.read(key: _keyPassword);
      if (username == null || password == null) {
        return false;
      }

      await login(username, password);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> getToken() => _storage.read(key: _keyToken);

  Future<String?> getUsername() => _storage.read(key: _keyUsername);

  Future<void> logout() async {
    await _storage.deleteAll();
  }

  /// The API returns dates like "2026-07-13 15:50", without a "T" separator
  /// or seconds, which DateTime.parse does not reliably accept. Parsed as a
  /// naive local datetime and compared against DateTime.now().
  DateTime? _parseExpiresAt(String value) {
    final parts = value.trim().split(RegExp(r'[ T]'));
    if (parts.isEmpty) return null;

    final dateParts = parts[0].split('-');
    if (dateParts.length != 3) return null;

    final timeParts = (parts.length > 1 ? parts[1] : '00:00')
        .split(':')
        .map((e) => e.split('.').first)
        .toList();

    try {
      return DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        timeParts.isNotEmpty ? int.parse(timeParts[0]) : 0,
        timeParts.length > 1 ? int.parse(timeParts[1]) : 0,
        timeParts.length > 2 ? int.parse(timeParts[2]) : 0,
      );
    } catch (_) {
      return null;
    }
  }
}
