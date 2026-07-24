import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Shown briefly on app start while it checks whether a saved session can
/// be restored, so the user isn't asked to log in every time.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _resolveInitialRoute();
  }

  Future<void> _resolveInitialRoute() async {
    final hasSession = await AuthService.instance.tryRestoreSession();
    if (hasSession) FcmService.instance.sincronizarToken();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => hasSession ? const HomeScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
