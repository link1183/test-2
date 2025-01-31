import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class AuthMiddleware extends StatefulWidget {
  final Widget child;
  final Widget loginScreen;

  const AuthMiddleware({
    required this.child,
    required this.loginScreen,
    super.key,
  });

  @override
  State<AuthMiddleware> createState() => _AuthMiddleware();
}

class _AuthMiddleware extends State<AuthMiddleware> {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      setState(() {
        _isLoading = false;
        _isAuthenticated = false;
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('/api/verify-token'),
        headers: {'Authorization': 'Bearer $token'},
      );

      setState(() {
        _isLoading = false;
        _isAuthenticated = response.statusCode == 200;
      });

      if (!_isAuthenticated) {
        await prefs.remove('token');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isAuthenticated = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _isAuthenticated ? widget.child : widget.loginScreen;
  }
}
