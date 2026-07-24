import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_app_movil/screens/login_screen.dart';

void main() {
  testWidgets('Login screen shows the username and password fields', (
    WidgetTester tester,
  ) async {
    // Pumped directly (skipping the splash screen) because it decides the
    // route based on flutter_secure_storage, which has no platform
    // implementation available in widget tests.
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Usuario'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Contraseña'), findsOneWidget);
  });
}
