import 'dart:convert';

import 'package:backend/middleware/rate_limit_middleware.dart';
import 'package:backend/services/auth_service.dart';
import 'package:backend/services/encryption_service.dart';
import 'package:backend/services/input_sanitizer.dart';
import 'package:backend/utils/api_response.dart';
import 'package:backend/utils/logger.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Controller that handles all authentication-related API endpoints.
class AuthController {
  final AuthService _authService;
  final EncryptionService _encryptionService;
  final RateLimitMiddleware _rateLimitMiddleware;
  final Logger _logger = LoggerFactory.getLogger('AuthController');

  AuthController(
      this._authService, this._encryptionService, this._rateLimitMiddleware);

  /// Returns the router with all authentication routes defined.
  Router get router {
    final router = Router();

    // Login route with rate limiting
    router.post(
        '/login',
        Pipeline()
            .addMiddleware(_rateLimitMiddleware.checkRateLimit)
            .addHandler(_handleLogin));

    // Refresh token route with rate limiting
    router.post(
        '/refresh-token',
        Pipeline()
            .addMiddleware(_rateLimitMiddleware.checkRateLimit)
            .addHandler(_handleRefreshToken));

    // Token verification route
    router.post('/verify-token', _handleVerifyToken);

    // Public key route
    router.get('/public-key', _handleGetPublicKey);

    return router;
  }

  /// Handler for GET /api/auth/public-key
  Future<Response> _handleGetPublicKey(Request request) async {
    return ApiResponse.ok({'publicKey': _encryptionService.publicKey});
  }

  /// Handler for POST /api/auth/login
  Future<Response> _handleLogin(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = InputSanitizer.sanitizeRequestBody(payload);

      if (data == null) {
        return ApiResponse.badRequest('Invalid request format');
      }

      final encryptedUsername = data['username'];
      final encryptedPassword = data['password'];

      if (encryptedUsername == null || encryptedPassword == null) {
        return ApiResponse.badRequest('Username and password required');
      }

      final username = _encryptionService.decrypt(encryptedUsername);
      final password = _encryptionService.decrypt(encryptedPassword);

      if (!InputSanitizer.isValidUsername(username)) {
        return ApiResponse.badRequest('Invalid username format');
      }

      if (!InputSanitizer.isValidPassword(password)) {
        return ApiResponse.badRequest('Invalid password format');
      }

      final sanitizedUsername = InputSanitizer.sanitizeLdapDN(username);
      final userData = await _authService.authenticateUser(
        sanitizedUsername,
        password,
      );

      if (userData == null) {
        return ApiResponse.unauthorized('Invalid credentials');
      }

      final tokenPair = _authService.generateTokenPair(userData, request);

      return ApiResponse.ok({
        'accessToken': tokenPair.accessToken,
        'refreshToken': tokenPair.refreshToken,
        'user': userData,
      });
    } catch (e, stackTrace) {
      _logger.error('Login error', e, stackTrace);
      return ApiResponse.serverError('Server error', details: e.toString());
    }
  }

  /// Handler for POST /api/auth/refresh-token
  Future<Response> _handleRefreshToken(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = json.decode(payload);
      final refreshToken = data['refreshToken'];

      if (refreshToken == null) {
        return ApiResponse.badRequest('Refresh token required');
      }

      final username = _authService.getUsernameFromRefreshToken(refreshToken);
      if (username == null) {
        return ApiResponse.unauthorized('Invalid refresh token');
      }

      if (!_authService.verifyRefreshToken(refreshToken, request)) {
        return ApiResponse.unauthorized('Invalid refresh token');
      }

      final userData = await _authService.getUserData(username);
      if (userData == null) {
        return ApiResponse.unauthorized('User no longer valid');
      }

      final tokenPair = _authService.generateTokenPair(userData, request);

      return ApiResponse.ok({
        'accessToken': tokenPair.accessToken,
        'refreshToken': tokenPair.refreshToken,
        'user': userData,
      });
    } catch (e, stackTrace) {
      _logger.error('Refresh token error', e, stackTrace);
      return ApiResponse.serverError('Server error', details: e.toString());
    }
  }

  /// Handler for POST /api/auth/verify-token
  Future<Response> _handleVerifyToken(Request request) async {
    try {
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return ApiResponse.unauthorized('No token provided');
      }

      final token = authHeader.substring(7);
      final isValid = _authService.verifyAccessToken(token, request);

      if (!isValid) {
        return ApiResponse.unauthorized('Invalid or expired token');
      }

      return ApiResponse.ok('Token valid');
    } catch (e, stackTrace) {
      _logger.error('Token verification error', e, stackTrace);
      return ApiResponse.serverError('Server error');
    }
  }
}
