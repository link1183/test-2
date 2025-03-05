import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:portail_it/middlewares/auth_provider.dart';
import 'package:portail_it/services/api_client.dart';
import 'package:portail_it/services/logger.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return authProvider.isAuthenticated ? widget.child : widget.loginScreen;
  }

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();

    final accessToken = prefs.getString('access_token');
    final refreshToken = prefs.getString('refresh_token');
    final userDataString = prefs.getString('user_data');

    if (refreshToken == null) {
      authProvider.setAuthenticated(false);
      setState(() => _isLoading = false);
      return;
    }

    try {
      if (accessToken != null) {
        final verifyResponse = await ApiClient.verifyToken(accessToken);

        if (verifyResponse.statusCode == 200) {
          await authProvider.setAuthenticated(
            true,
            accessToken: accessToken,
            refreshToken: refreshToken,
            userData:
                userDataString != null ? json.decode(userDataString) : null,
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      final refreshSuccess = await _refreshTokens(refreshToken, authProvider);

      if (!refreshSuccess) {
        await authProvider.setAuthenticated(false);
      }
    } catch (e, stackTrace) {
      Logger.error('Error during auth check', e, stackTrace);
      authProvider.setAuthenticated(false);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _refreshTokens(
      String refreshToken, AuthProvider authProvider) async {
    try {
      final response = await ApiClient.refreshToken(refreshToken);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final accessToken = data['accessToken'];
        final newRefreshToken = data['refreshToken'];
        final userData = data['user'];

        await authProvider.setAuthenticated(
          true,
          accessToken: accessToken,
          refreshToken: newRefreshToken,
          userData: userData,
        );
        return true;
      }
    } catch (e, stackTrace) {
      Logger.error('Error refreshing tokens', e, stackTrace);
    }
    return false;
  }
}
