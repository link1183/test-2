import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:portail_it/middlewares/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:portail_it/services/api_client.dart';

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
      final response = await ApiClient.post('/api/verify-token');

      final isValid = response.statusCode == 200;

      if (isValid) {
        authProvider.setAuthenticated(true, token: token);
      } else {
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
