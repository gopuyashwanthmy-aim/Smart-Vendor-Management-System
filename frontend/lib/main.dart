import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'screens/login_page.dart';

void main() {
  final authService = AuthService();
  runApp(SmartVendorApp(authService: authService));
}

class SmartVendorApp extends StatelessWidget {
  final AuthService authService;
  const SmartVendorApp({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF2E7D32);
    const pale = Color(0xFFF2F8F1);
    return MaterialApp(
      title: 'Smart Vendor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: green, brightness: Brightness.light).copyWith(
          primary: green,
          surface: Colors.white,
          surfaceContainer: const Color(0xFFEAF4E8),
          secondary: const Color(0xFF7CB342),
        ),
        scaffoldBackgroundColor: pale,
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFE4F1E1), foregroundColor: Color(0xFF194D24), elevation: 0, centerTitle: false),
        cardTheme: CardThemeData(color: Colors.white, elevation: 1, margin: const EdgeInsets.symmetric(vertical: 6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
        inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: const Color(0xFFF7FBF6), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD5E6D2))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD5E6D2)))),
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13))),
      ),
      home: LoginPage(authService: authService),
    );
  }
}
