import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:portail_it/services/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _accessToken;
  String? _refreshToken;
  Timer? _refreshTimer;
  Map<String, dynamic>? _userData;

  bool get isAuthenticated => _isAuthenticated;
  String? get accessToken => _accessToken;
  Map<String, dynamic>? get userData => _userData;
  String? get displayName => _userData?['name'];
  String? get email => _userData?['email'];
  String? get username => _userData?['sub'];

  Future<void> setAuthenticated(
    bool value, {
    String? accessToken,
    String? refreshToken,
    Map<String, dynamic>? userData,
  }) async {
    _isAuthenticated = value;

    if (value && accessToken != null && refreshToken != null) {
      _accessToken = accessToken;
      _refreshToken = refreshToken;
      _userData = userData;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', accessToken);
      await prefs.setString('refresh_token', refreshToken);
      if (userData != null) {
        await prefs.setString('user_data', json.encode(userData));
      }

      _setupRefreshTimer();
    } else {
      _accessToken = null;
      _refreshToken = null;
      _userData = null;
      _refreshTimer?.cancel();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      await prefs.remove('user_data');
    }

    notifyListeners();
  }

  void _setupRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 14), (_) {
      _refreshAccessToken();
    });
  }

  Future<bool> _refreshAccessToken() async {
    Logger.info('Attempting to refresh access token');
    if (_refreshToken == null) {
      Logger.warning('No refresh token available');
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('/api/refresh-token'),
        body: json.encode({'refreshToken': _refreshToken}),
        headers: {'Content-Type': 'application/json'},
      );

      Logger.info('Refresh token response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await setAuthenticated(
          true,
          accessToken: data['accessToken'],
          refreshToken: data['refreshToken'],
          userData: data['user'],
        );
        Logger.info('Token refresh successful');
        return true;
      } else {
        Logger.warning(
            'Token refresh failed with status: ${response.statusCode}');
        await setAuthenticated(false);
        return false;
      }
    } catch (e) {
      Logger.error('Error refreshing token', e);
      await setAuthenticated(false);
      return false;
    }
  }

  Future<void> checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token');

    if (_refreshToken != null) {
      _refreshToken = refreshToken;
      if (await _refreshAccessToken()) {
        return;
      }
    }

    await setAuthenticated(false);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    _userData = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}
