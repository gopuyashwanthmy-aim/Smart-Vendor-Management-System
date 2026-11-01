import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class AuthService {
  static const String baseUrl = AppConfig.apiBaseUrl;

  String? _token;
  Map<String, dynamic>? _user;

  String? get token => _token;

  Map<String, dynamic>? get user => _user;

  String? get role => _user?['role'];

  Future<void> login({
    required String phone,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'phone': phone,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      _token = data['access_token'];
      _user = data['user'];

      return;
    }

    throw Exception(
      'Login failed: ${response.body}',
    );
  }


  Future<void> register({
    required String name,
    required String phone,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'phone': phone,
        'password': password,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Registration failed: ${response.body}');
    }
  }

  void logout() {
    _token = null;
    _user = null;
  }
}