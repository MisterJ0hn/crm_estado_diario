import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'auth_service.dart';
import 'estado_diario_service.dart';

/// Registers this device with Firebase Cloud Messaging and keeps the
/// backend's copy of the FCM token in sync for the logged-in user.
///
/// Only wired for Android for now, since that's the only platform
/// registered in the Firebase project (google-services.json).
class FcmService {
  FcmService._();

  static final FcmService instance = FcmService._();

  bool _inicializado = false;

  /// Initializes Firebase, requests notification permission and starts
  /// listening for token refreshes. Safe to call more than once. Failures
  /// are swallowed: push notifications are not critical to app usage.
  Future<void> inicializar() async {
    if (_inicializado || !Platform.isAndroid) return;
    _inicializado = true;

    try {
      await Firebase.initializeApp();
      await FirebaseMessaging.instance.requestPermission();
      FirebaseMessaging.instance.onTokenRefresh.listen(_registrarToken);
      await sincronizarToken();
    } catch (_) {
      // Best-effort.
    }
  }

  /// Fetches the current FCM token and sends it to the backend for the
  /// logged-in user, if any. Call this again right after a successful
  /// login or session restore, since the token may have been obtained
  /// before the username was known.
  Future<void> sincronizarToken() async {
    if (!Platform.isAndroid) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _registrarToken(token);
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> _registrarToken(String token) async {
    final username = await AuthService.instance.getUsername();
    if (username == null) return;

    try {
      await EstadoDiarioService.instance.registrarTokenFcm(
        username: username,
        token: token,
        plataforma: 'android',
      );
    } catch (_) {
      // Best-effort.
    }
  }
}
