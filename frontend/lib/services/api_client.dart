import 'dart:async';
import 'dart:convert';

import 'package:encrypt/encrypt.dart';
import 'package:http/http.dart' as http;
import 'package:portail_it/services/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static bool _isRefreshing = false;
  static final List<Function> _refreshSubscribers = [];

  static Future<http.Response> delete(String endpoint) async {
    return _executeRequest(() async {
      final token = await _getAccessToken();
      return http.delete(
        Uri.parse(endpoint),
        headers: {
          'content-type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
    });
  }

  static Future<http.Response> get(String endpoint) async {
    return _executeRequest(() async {
      final token = await _getAccessToken();
      return http.get(
        Uri.parse(endpoint),
        headers: {
          'content-type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
    });
  }

  static Future<http.Response> login(
    String username,
    String password,
    Encrypter encrypter,
  ) async {
    final encryptedUsername = encrypter.encrypt(username);
    final encryptedPassword = encrypter.encrypt(password);

    return http.post(
      Uri.parse('/api/login'),
      headers: {'content-type': 'application/json'},
      body: json.encode({
        'username': encryptedUsername.base64,
        'password': encryptedPassword.base64,
      }),
    );
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_data');
  }

  static Future<http.Response> post(String endpoint, {Object? body}) async {
    return _executeRequest(() async {
      final token = await _getAccessToken();
      return http.post(
        Uri.parse(endpoint),
        headers: {
          'content-type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: body is String ? body : (body != null ? json.encode(body) : null),
      );
    });
  }

  static Future<http.Response> put(String endpoint, {Object? body}) async {
    return _executeRequest(() async {
      final token = await _getAccessToken();
      return http.put(
        Uri.parse(endpoint),
        headers: {
          'content-type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: body is String ? body : (body != null ? json.encode(body) : null),
      );
    });
  }

  static Future<http.Response> refreshToken(String refreshToken) async {
    return http.post(
      Uri.parse('/api/refresh-token'),
      headers: {'content-type': 'application/json'},
      body: json.encode({'refreshToken': refreshToken}),
    );
  }

  static Future<http.Response> verifyToken(String token) async {
    return http.post(
      Uri.parse('/api/verify-token'),
      headers: {
        'content-type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
  }

  static void _addRefreshSubscriber(Function callback) {
    _refreshSubscribers.add(callback);
  }

  static Future<http.Response> _executeRequest(
    Future<http.Response> Function() requestFunction,
  ) async {
    try {
      final response = await requestFunction();

      if (response.statusCode == 401) {
        if (!_isRefreshing) {
          _isRefreshing = true;
          final refreshSuccess = await _refreshTokens();
          _isRefreshing = false;

          if (refreshSuccess) {
            _notifySubscribers();
            return await requestFunction();
          }
        } else {
          final completer = Completer<http.Response>();
          _addRefreshSubscriber(() async {
            try {
              final response = await requestFunction();
              completer.complete(response);
            } catch (e) {
              completer.completeError(e);
            }
          });
          return completer.future;
        }
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  static Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<String?> _getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  static void _notifySubscribers() {
    for (var callback in _refreshSubscribers) {
      callback();
    }

    _refreshSubscribers.clear();
  }

  static Future<bool> _refreshTokens() async {
    try {
      final refreshToken = await _getRefreshToken();
      if (refreshToken == null) return false;

      final response = await http.post(
        Uri.parse('/api/refresh-token'),
        headers: {'content-type': 'application/json'},
        body: json.encode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString('access_token', data['access_token']);
        await prefs.setString('refresh_token', data['refresh_token']);
        if (data['user'] != null) {
          await prefs.setString('user_data', json.encode(data['user']));
        }

        return true;
      }
      return false;
    } catch (e, stackTrace) {
      Logger.error('Error refreshing tokens', e, stackTrace);
      return false;
    }
  }
}
