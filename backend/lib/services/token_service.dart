import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class TokenService {
  final String jwtSecret;
  final Duration accessTokenDuration;
  final Duration refreshTokenDuration;

  TokenService({
    required this.jwtSecret,
    this.accessTokenDuration = const Duration(minutes: 15),
    this.refreshTokenDuration = const Duration(days: 7),
  });

  TokenPair generateTokenPair(Map<String, dynamic> userData) {
    final accessToken = _generateAccessToken(userData);
    final refreshToken = _generateRefreshToken(userData['username']);

    return TokenPair(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  String _generateAccessToken(Map<String, dynamic> userData) {
    final claims = JWT(
      {
        'sub': userData['username'],
        'name': userData['displayName'],
        'email': userData['email'],
        'groups': userData['groups'],
        'type': 'access',
        'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'exp': DateTime.now().add(accessTokenDuration).millisecondsSinceEpoch ~/
            1000,
      },
    );

    return claims.sign(SecretKey(jwtSecret));
  }

  String _generateRefreshToken(String username) {
    final claims = JWT(
      {
        'sub': username,
        'type': 'refresh',
        'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'exp':
            DateTime.now().add(refreshTokenDuration).millisecondsSinceEpoch ~/
                1000,
      },
    );

    return claims.sign(SecretKey(jwtSecret));
  }

  bool verifyAccessToken(String token) {
    try {
      final JWT jwt = JWT.verify(token, SecretKey(jwtSecret));
      return jwt.payload['type'] == 'access';
    } catch (e) {
      return false;
    }
  }

  bool verifyRefreshToken(String token) {
    try {
      final JWT jwt = JWT.verify(token, SecretKey(jwtSecret));
      return jwt.payload['type'] == 'refresh';
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
