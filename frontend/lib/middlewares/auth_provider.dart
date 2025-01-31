import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _displayName;
  String? _email;

  bool get isAuthenticated => _isAuthenticated;
  String? get displayName => _displayName;
  String? get email => _email;

  Future<void> checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    _isAuthenticated = token != null;
    _displayName = prefs.getString('displayName');
    _email = prefs.getString('email');

    notifyListeners();
  }

  Future<void> setAuthenticated(bool value,
      {String? name, String? email}) async {
    _isAuthenticated = value;
    _displayName = name;
    _email = email;
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('displayName');
    await prefs.remove('email');

    _isAuthenticated = false;
    _displayName = null;
    _email = null;

    notifyListeners();
  }
}
