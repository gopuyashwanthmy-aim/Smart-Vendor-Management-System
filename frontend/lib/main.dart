import 'package:flutter/material.dart';

import 'services/auth_service.dart';
import 'screens/login_page.dart';

void main() {
  final authService = AuthService();

  runApp(
    SmartVendorApp(
      authService: authService,
    ),
  );
}

class SmartVendorApp extends StatelessWidget {
  final AuthService authService;

  const SmartVendorApp({
    super.key,
    required this.authService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Vendor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: LoginPage(
        authService: authService,
      ),
    );
  }
}