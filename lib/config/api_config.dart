import 'package:shared_preferences/shared_preferences.dart';

/// Holds the API base URL. It ships with a default value but can be
/// changed at runtime (and is persisted) without recompiling the app,
/// since the real address is expected to change over time.
class ApiConfig {
  ApiConfig._();

  static const String defaultBaseUrl = 'http://ejamtest.codifica.cl/api';
  static const String _prefsKey = 'api_base_url';

  static String? _cachedBaseUrl;

  static Future<String> getBaseUrl() async {
    if (_cachedBaseUrl != null) return _cachedBaseUrl!;
    final prefs = await SharedPreferences.getInstance();
    _cachedBaseUrl = prefs.getString(_prefsKey) ?? defaultBaseUrl;
    return _cachedBaseUrl!;
  }

  static Future<void> setBaseUrl(String url) async {
    final normalized = _normalize(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, normalized);
    _cachedBaseUrl = normalized;
  }

  static String _normalize(String url) {
    final trimmed = url.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}
