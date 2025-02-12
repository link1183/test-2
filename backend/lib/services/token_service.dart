import 'dart:collection';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';

class TokenService {
  final String jwtSecret;
  final Duration accessTokenDuration;
  final Duration refreshTokenDuration;

  final Set<String> _usedRefreshTokens = {};

  final Map<String, Queue<DateTime>> _rateLimitAttempts = {};
  final int _maxAttemptsPerWindow;
  final Duration _rateLimitWindow;

  TokenService({
    required this.jwtSecret,
    this.accessTokenDuration = const Duration(minutes: 15),
    this.refreshTokenDuration = const Duration(days: 7),
    int maxAttemptsPerWindow = 5,
    Duration? rateLimitWindow,
  })  : _maxAttemptsPerWindow = maxAttemptsPerWindow,
        _rateLimitWindow = rateLimitWindow ?? const Duration(minutes: 5);

  String generateFingerPrint(Request request) {
    final userAgent = request.headers['user-agent'] ?? 'unknown';
    final ip = request.headers['x-forwarded-for']?.split(',').first.trim() ??
        request.headers['x-real-ip'] ??
        'unknown';
    return Object.hash(userAgent, ip).toString();
  }

  bool checkRateLimit(String ip) {
    final now = DateTime.now();

    _rateLimitAttempts[ip] = _rateLimitAttempts[ip] ?? Queue<DateTime>();
    while (_rateLimitAttempts[ip]!.isNotEmpty &&
        now.difference(_rateLimitAttempts[ip]!.first) > _rateLimitWindow) {
      _rateLimitAttempts[ip]!.removeFirst();
    }

    if (_rateLimitAttempts[ip]!.length >= _maxAttemptsPerWindow) {
      return false;
    }

    _rateLimitAttempts[ip]!.add(now);
    return true;
  }

  TokenPair generateTokenPair(
      Map<String, dynamic> userData, String fingerprint) {
    final accessToken = _generateAccessToken(userData, fingerprint);
    final refreshToken =
        _generateRefreshToken(userData['username'], fingerprint);

    return TokenPair(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  String _generateAccessToken(
      Map<String, dynamic> userData, String fingerprint) {
    final claims = JWT(
      {
        'sub': userData['username'],
        'name': userData['displayName'],
        'email': userData['email'],
        'groups': userData['groups'],
        'type': 'access',
        'fingerprint': fingerprint,
        'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'exp': DateTime.now().add(accessTokenDuration).millisecondsSinceEpoch ~/
            1000,
      },
    );

    return claims.sign(SecretKey(jwtSecret));
  }

  String _generateRefreshToken(String username, String fingerprint) {
    final claims = JWT(
      {
        'sub': username,
        'type': 'refresh',
        'fingerprint': fingerprint,
        'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'exp':
            DateTime.now().add(refreshTokenDuration).millisecondsSinceEpoch ~/
                1000,
      },
    );

    return claims.sign(SecretKey(jwtSecret));
  }

  bool verifyAccessToken(String token, String fingerprint) {
    try {
      final JWT jwt = JWT.verify(token, SecretKey(jwtSecret));
      return jwt.payload['type'] == 'access' &&
          jwt.payload['fingerprint'] == fingerprint;
    } catch (e) {
      return false;
    }
  }

  bool verifyRefreshToken(String token, String fingerprint) {
    try {
      if (_usedRefreshTokens.contains(token)) {
        return false;
      }

      final JWT jwt = JWT.verify(token, SecretKey(jwtSecret));
      if (jwt.payload['type'] != 'refresh' ||
          jwt.payload['fingerprint'] != fingerprint) {
        return false;
      }

      _usedRefreshTokens.add(token);

      _cleanupUsedTokens();

      return true;
    } catch (e) {
      return false;
    }
  }

  String? getUsernameFromRefreshToken(String token) {
    try {
      final JWT jwt = JWT.verify(token, SecretKey(jwtSecret));
      return jwt.payload['sub'] as String?;
    } catch (e) {
      return null;
    }
  }

  void _cleanupUsedTokens() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _usedRefreshTokens.removeWhere((token) {
      try {
        final JWT jwt = JWT.verify(token, SecretKey(jwtSecret));
        return (jwt.payload['exp'] as int) < now;
      } catch (e) {
        return true;
      }
    });
  }
}

class TokenPair {
  final String accessToken;
  final String refreshToken;

  TokenPair({
    required this.accessToken,
    required this.refreshToken,
  });

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
      };
}
