import 'dart:convert';

import 'package:backend/db/database.dart';
import 'package:backend/services/auth_service.dart';
import 'package:backend/services/encryption_service.dart';
import 'package:backend/services/input_sanitizer.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class Api {
  final AppDatabase db;
  final AuthService authService;
  final EncryptionService encryptionService;

  Api({required this.authService})
      : db = AppDatabase(enableLogging: true),
        encryptionService = EncryptionService() {
    db.init();
  }

  Router get router {
    final router = Router();

    router.post('/refresh-token', (Request request) async {
      try {
        if (!authService.checkRateLimit(request)) {
          return Response(429, body: 'Too many attempts');
        }

        final payload = await request.readAsString();
        final data = json.decode(payload);
        final refreshToken = data['refreshToken'];

        if (refreshToken == null) {
          return Response(400, body: 'Refresh token required');
        }

        final username = authService.getUsernameFromRefreshToken(refreshToken);
        if (username == null) {
          return Response(401, body: 'Invalid refresh token');
        }

        if (!authService.verifyRefreshToken(refreshToken, request)) {
          return Response(401, body: 'Invalid refresh token');
        }

        final userData = await authService.getUserData(username);
        if (userData == null) {
          return Response(401, body: 'User no longer valid');
        }

        final tokenPair = authService.generateTokenPair(userData, request);

        return Response.ok(
          json.encode({
            'accessToken': tokenPair.accessToken,
            'refreshToken': tokenPair.refreshToken,
            'user': userData,
          }),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(body: 'Server error: $e');
      }
    });

    router.get('/categories', (Request request) async {
      try {
        final authHeader = request.headers['authorization'];
        if (authHeader == null || !authHeader.startsWith('Bearer ')) {
          return Response(401, body: 'No token provided');
        }

        final token = authHeader.substring(
          7,
        ); // We remove the "bearer: " part, which is 7 chars
        if (!authService.verifyAccessToken(token, request)) {
          return Response(401, body: 'Invalid token');
        }

        final decodedToken = JwtDecoder.decode(token);
        final userGroups =
            (decodedToken['groups'] as List<dynamic>?)?.cast<String>() ?? [];

        if (userGroups.isEmpty) {
          return Response.ok(
            jsonEncode({'categories': []}),
            headers: {'content-type': 'application/json'},
          );
        }

        final categories = db.getCategoriesForUser(userGroups);

        final filteredCategories = categories
            .where(
              (category) => (category['links'] as List).isNotEmpty,
            )
            .toList();

        return Response.ok(
          jsonEncode({'categories': filteredCategories}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode(
              {'error': 'Internal server error', 'details': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    router.get('/admin/db-stats', (Request request) async {
      try {
        final authHeader = request.headers['authorization'];
        if (authHeader == null || !authHeader.startsWith('Bearer ')) {
          return Response(401, body: 'No token provided');
        }

        final token = authHeader.substring(7);
        if (!authService.verifyAccessToken(token, request)) {
          return Response(401, body: 'Invalid token');
        }

        // Check if user is an admin
        final decodedToken = JwtDecoder.decode(token);
        final userGroups =
            (decodedToken['groups'] as List<dynamic>?)?.cast<String>() ?? [];

        if (!userGroups.contains('admin') && !userGroups.contains('si-bcu-g')) {
          return Response(403, body: 'Insufficient permissions');
        }

        final stats = db.getDatabaseStats();

        return Response.ok(
          jsonEncode({'stats': stats}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'error': 'Internal server error'}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    router.post('/admin/db-backup', (Request request) async {
      try {
        final authHeader = request.headers['authorization'];
        if (authHeader == null || !authHeader.startsWith('Bearer ')) {
          return Response(401, body: 'No token provided');
        }

        final token = authHeader.substring(7);
        if (!authService.verifyAccessToken(token, request)) {
          return Response(401, body: 'Invalid token');
        }

        final decodedToken = JwtDecoder.decode(token);
        final userGroups =
            (decodedToken['groups'] as List<dynamic>?)?.cast<String>() ?? [];

        if (!userGroups.contains('admin') && !userGroups.contains('si-bcu-g')) {
          return Response(403, body: 'Insufficient permissions');
        }

        final timestamp = DateTime.now()
            .toIso8601String()
            .replaceAll(':', '-')
            .replaceAll('.', '-');
        final backupPath = '/data/backup_$timestamp.db';

        final success = await db.backup(backupPath);

        if (success) {
          return Response.ok(
            jsonEncode({'success': true, 'path': backupPath}),
            headers: {'content-type': 'application/json'},
          );
        } else {
          return Response.internalServerError(
            body: jsonEncode({'error': 'Backup failed'}),
            headers: {'content-type': 'application/json'},
          );
        }
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode(
              {'error': 'Internal server error', 'details': e.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // Auth endpoints
    router.get('/public-key', (Request request) {
      return Response.ok(
        json.encode({'publicKey': encryptionService.publicKey}),
        headers: {'content-type': 'application/json'},
      );
    });

    router.post('/login', (Request request) async {
      try {
        if (!authService.checkRateLimit(request)) {
          return Response(429, body: 'Too many attempts');
        }

        final payload = await request.readAsString();
        final data = InputSanitizer.sanitizeRequestBody(payload);

        if (data == null) {
          return Response(400, body: 'Invalid request format');
        }

        final encryptedUsername = data['username'];
        final encryptedPassword = data['password'];

        if (encryptedUsername == null || encryptedPassword == null) {
          return Response(400, body: 'Username and password required');
        }

        final username = encryptionService.decrypt(encryptedUsername);
        final password = encryptionService.decrypt(encryptedPassword);

        if (!InputSanitizer.isValidUsername(username)) {
          return Response(400, body: 'Invalid username format');
        }

        if (!InputSanitizer.isValidPassword(password)) {
          return Response(400, body: 'Invalid password format');
        }

        final sanitizedUsername = InputSanitizer.sanitizeLdapDN(username);
        final userData = await authService.authenticateUser(
          sanitizedUsername,
          password,
        );

        if (userData == null) {
          return Response(401, body: 'Invalid credentials');
        }

        final tokenPair = authService.generateTokenPair(userData, request);

        return Response.ok(
          json.encode({
            'accessToken': tokenPair.accessToken,
            'refreshToken': tokenPair.refreshToken,
            'user': userData,
          }),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(body: 'Server error: $e');
      }
    });

    router.post('/verify-token', (Request request) {
      try {
        final authHeader = request.headers['authorization'];
        if (authHeader == null || !authHeader.startsWith('Bearer ')) {
          return Response(401, body: 'No token provided');
        }

        final token = authHeader.substring(7);
        final isValid = authService.verifyAccessToken(token, request);

        if (!isValid) {
          return Response(401, body: 'Invalid or expired token');
        }

        return Response.ok('Token valid');
      } catch (e) {
        return Response.internalServerError(body: 'Server error');
      }
    });

    return router;
  }

  void dispose() {
    db.dispose();
  }
}
