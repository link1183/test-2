import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  Map<String, dynamic>? _userData;

  bool get isAuthenticated => _isAuthenticated;
  String? get displayName => _userData?['name'];
  String? get email => _userData?['email'];
  String? get username => _userData?['sub'];

  Future<void> checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token != null) {
      try {
        final decodedToken = JwtDecoder.decode(token);
        _userData = decodedToken;
        _isAuthenticated = true;
      } catch (e) {
        _userData = null;
        _isAuthenticated = false;
        await prefs.remove('token');
      }
    } else {
      _userData = null;
      _isAuthenticated = false;
    }

    notifyListeners();
  }

  Future<void> setAuthenticated(bool value, {String? token}) async {
    final prefs = await SharedPreferences.getInstance();

    if (value && token != null) {
      await prefs.setString('token', token);
      _userData = JwtDecoder.decode(token);
      _isAuthenticated = true;
    } else {
      await prefs.remove('token');
      _userData = null;
      _isAuthenticated = false;
    }

    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    _userData = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}
