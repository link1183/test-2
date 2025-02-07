import 'package:encrypt/encrypt.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ApiClient {
  static Future<http.Response> get(String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    return http.get(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
  }

  static Future<http.Response> post(String endpoint, {Object? body}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    return http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: body is String ? body : (body != null ? json.encode(body) : null),
    );
  }

  // Special method for login that doesn't require token
  static Future<http.Response> login(
      String username, String password, Encrypter encrypter) async {
    final encryptedUsername = encrypter.encrypt(username);
    final encryptedPassword = encrypter.encrypt(password);

    return post(
      '/api/login',
      body: {
        'username': encryptedUsername.base64,
        'password': encryptedPassword.base64,
      },
    );
  }
}
