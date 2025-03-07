import 'dart:convert';

import 'package:backend/db/database.dart';
import 'package:backend/middleware/auth_middleware.dart';
import 'package:backend/middleware/rate_limit_middleware.dart';
import 'package:backend/services/auth_service.dart';
import 'package:backend/services/category_service.dart';
import 'package:backend/services/encryption_service.dart';
import 'package:backend/services/input_sanitizer.dart';
import 'package:backend/utils/api_response.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class Api {
  final AppDatabase db;
  final AuthService authService;
  final EncryptionService encryptionService;
  final AuthMiddleware _authMiddleware;
  final RateLimitMiddleware _rateLimitMiddleware;
  late CategoryService categoryService;

  Api({required this.authService})
      : db = AppDatabase(enableLogging: true),
        encryptionService = EncryptionService(),
        _authMiddleware = AuthMiddleware(authService),
        _rateLimitMiddleware = RateLimitMiddleware(authService) {
    db.init();
    categoryService = CategoryService(db);
  }

  Router get router {
    final router = Router();

    // Auth routes
    router.post(
        '/login',
        Pipeline()
            .addMiddleware(_rateLimitMiddleware.checkRateLimit)
            .addHandler(_handleLogin));

    router.post(
        '/refresh-token',
        Pipeline()
            .addMiddleware(_rateLimitMiddleware.checkRateLimit)
            .addHandler(_handleRefreshToken));

    router.post('/verify-token', _handleVerifyToken);

    router.get('/public-key', _handleGetPublicKey);

    // Data routes - require authentication
    router.get(
        '/categories',
        Pipeline()
            .addMiddleware(_authMiddleware.requireAuth)
            .addHandler(_handleGetCategories));

    // Admin routes - require admin privileges
    router.get(
        '/admin/db-stats',
        Pipeline()
            .addMiddleware(_authMiddleware.requireAdmin)
            .addHandler(_handleGetDbStats));

    router.post(
        '/admin/db-backup',
        Pipeline()
            .addMiddleware(_authMiddleware.requireAdmin)
            .addHandler(_handleDbBackup));

    return router;
  }

  void dispose() {
    db.dispose();
  }

  Future<Response> _handleDbBackup(Request request) async {
    try {
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final backupPath = '/data/backup_$timestamp.db';

      final success = await db.backup(backupPath);

      if (success) {
        return ApiResponse.ok({'success': true, 'path': backupPath});
      } else {
        return ApiResponse.serverError('Backup failed');
      }
    } catch (e) {
      return ApiResponse.serverError('Error creating database backup',
          details: e.toString());
    }
  }

  Future<Response> _handleGetCategories(Request request) async {
    try {
      final authHeader = request.headers['authorization'];
      final token = authHeader!.substring(7); // Already validated by middleware

      final userGroups = authService.getGroupsFromToken(token);

      final categories = await categoryService.getCategoriesForUser(userGroups);

      return ApiResponse.ok({'categories': categories});
    } catch (e) {
      return ApiResponse.serverError('Error retrieving categories',
          details: e.toString());
    }
  }

  Future<Response> _handleGetDbStats(Request request) async {
    try {
      final stats = db.getDatabaseStats();
      return ApiResponse.ok({'stats': stats});
    } catch (e) {
      return ApiResponse.serverError('Error retrieving database statistics',
          details: e.toString());
    }
  }

  Future<Response> _handleGetPublicKey(Request request) async {
    return ApiResponse.ok({'publicKey': encryptionService.publicKey});
  }

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

      final username = encryptionService.decrypt(encryptedUsername);
      final password = encryptionService.decrypt(encryptedPassword);

      if (!InputSanitizer.isValidUsername(username)) {
        return ApiResponse.badRequest('Invalid username format');
      }

      if (!InputSanitizer.isValidPassword(password)) {
        return ApiResponse.badRequest('Invalid password format');
      }

      final sanitizedUsername = InputSanitizer.sanitizeLdapDN(username);
      final userData = await authService.authenticateUser(
        sanitizedUsername,
        password,
      );

      if (userData == null) {
        return ApiResponse.unauthorized('Invalid credentials');
      }

      final tokenPair = authService.generateTokenPair(userData, request);

      return ApiResponse.ok({
        'accessToken': tokenPair.accessToken,
        'refreshToken': tokenPair.refreshToken,
        'user': userData,
      });
    } catch (e) {
      return ApiResponse.serverError('Server error', details: e.toString());
    }
  }

  Future<Response> _handleRefreshToken(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = json.decode(payload);
      final refreshToken = data['refreshToken'];

      if (refreshToken == null) {
        return ApiResponse.badRequest('Refresh token required');
      }

      final username = authService.getUsernameFromRefreshToken(refreshToken);
      if (username == null) {
        return ApiResponse.unauthorized('Invalid refresh token');
      }

      if (!authService.verifyRefreshToken(refreshToken, request)) {
        return ApiResponse.unauthorized('Invalid refresh token');
      }

      final userData = await authService.getUserData(username);
      if (userData == null) {
        return ApiResponse.unauthorized('User no longer valid');
      }

      final tokenPair = authService.generateTokenPair(userData, request);

      return ApiResponse.ok({
        'accessToken': tokenPair.accessToken,
        'refreshToken': tokenPair.refreshToken,
        'user': userData,
      });
    } catch (e) {
      return ApiResponse.serverError('Server error', details: e.toString());
    }
  }

  Future<Response> _handleVerifyToken(Request request) async {
    try {
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return ApiResponse.unauthorized('No token provided');
      }

      final token = authHeader.substring(7);
      final isValid = authService.verifyAccessToken(token, request);

      if (!isValid) {
        return ApiResponse.unauthorized('Invalid or expired token');
      }

      return ApiResponse.ok('Token valid');
    } catch (e) {
      return ApiResponse.serverError('Server error');
    }
  }
}
