import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'services/fcm_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FcmService.instance.inicializar();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Estado Diario',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const SplashScreen(),
    );
  }
}
