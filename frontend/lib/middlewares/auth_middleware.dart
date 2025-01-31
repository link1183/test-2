import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test/middlewares/auth_provider.dart';
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
  State<AuthMiddleware> createState() => _AuthMiddlewareState();
}

class _AuthMiddlewareState extends State<AuthMiddleware> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      authProvider.setAuthenticated(false);
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('/api/verify-token'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final isValid = response.statusCode == 200;
      authProvider.setAuthenticated(isValid);

      if (isValid) {
        authProvider.setAuthenticated(true,
            name: prefs.getString('displayName'),
            email: prefs.getString('email'));
      } else {
        await prefs.remove('token');
        await prefs.remove('displayName');
        await prefs.remove('email');
        authProvider.setAuthenticated(false);
      }
    } catch (e) {
      authProvider.setAuthenticated(false);
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return authProvider.isAuthenticated ? widget.child : widget.loginScreen;
  }
}
