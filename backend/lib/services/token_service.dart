import 'dart:collection';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';

class TokenService {
  final String jwtSecret;
  final Duration accessTokenDuration;
  final Duration refreshTokenDuration;

  final Set<String> _blacklistedTokens = {};
  final Map<String, int> _blacklistedTokenExpiry = {};

  final String _tokenVersion;

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
        _rateLimitWindow = rateLimitWindow ?? const Duration(minutes: 5),
        _tokenVersion = DateTime.now().toIso8601String();

  String _generateUniqueId() => Uuid().v4().toString();

  void blacklistToken(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(jwtSecret));
      final exp = jwt.payload['exp'] as int;
      _blacklistedTokens.add(token);
      _blacklistedTokenExpiry[token] = exp;
      _cleanupBlacklist();
    } catch (e) {
      print('Attempt to blacklist invalid token: $e');
    }
  }

  void _cleanupBlacklist() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _blacklistedTokens.removeWhere((token) {
      final expiry = _blacklistedTokenExpiry[token];
      if (expiry == null || expiry < now) {
        _blacklistedTokenExpiry.remove(token);
        return true;
      }
      return false;
    });
  }

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
        'version': _tokenVersion,
        'jti': _generateUniqueId(),
        'aud': 'portail-it',
        'iss': 'portail-it-auth',
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
        'version': _tokenVersion,
        'jti': _generateUniqueId(),
        'aud': 'portail-it',
        'iss': 'portail-it-auth',
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
      if (_blacklistedTokens.contains(token)) {
        return false;
      }

      final JWT jwt = JWT.verify(token, SecretKey(jwtSecret));

      return jwt.payload['type'] == 'access' &&
          jwt.payload['fingerprint'] == fingerprint &&
          jwt.payload['version'] == _tokenVersion &&
          jwt.payload['aud'] == 'portail-it' &&
          jwt.payload['iss'] == 'portail-it-auth';
    } catch (e) {
      return false;
    }
  }

  bool verifyRefreshToken(String token, String fingerprint) {
    try {
      if (_blacklistedTokens.contains(token)) {
        return false;
      }

      final JWT jwt = JWT.verify(token, SecretKey(jwtSecret));
      if (jwt.payload['type'] != 'refresh' ||
          jwt.payload['fingerprint'] != fingerprint ||
          jwt.payload['version'] != _tokenVersion ||
          jwt.payload['aud'] != 'portail-it' ||
          jwt.payload['iss'] != 'portail-it-auth') {
        return false;
      }

      blacklistToken(token);

      return true;
    } catch (e) {
      return false;
    }
  }

  String? getUsernameFromRefreshToken(String token) {
    try {
      if (_blacklistedTokens.contains(token)) {
        return null;
      }

      final JWT jwt = JWT.verify(token, SecretKey(jwtSecret));
      if (jwt.payload['version'] != _tokenVersion) {
        return null;
      }
      return jwt.payload['sub'] as String?;
    } catch (e) {
      return null;
    }
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
