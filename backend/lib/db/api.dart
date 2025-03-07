import 'dart:convert';

import 'package:backend/db/database.dart';
import 'package:backend/middleware/auth_middleware.dart';
import 'package:backend/middleware/rate_limit_middleware.dart';
import 'package:backend/services/auth_service.dart';
import 'package:backend/services/category_service.dart';
import 'package:backend/services/encryption_service.dart';
import 'package:backend/services/input_sanitizer.dart';
import 'package:backend/services/status_service.dart';
import 'package:backend/utils/api_response.dart';
import 'package:backend/utils/logger.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class Api {
  final AppDatabase db;
  final AuthService authService;
  final EncryptionService encryptionService;
  final AuthMiddleware _authMiddleware;
  final RateLimitMiddleware _rateLimitMiddleware;
  late CategoryService categoryService;
  late StatusService statusService;

  Api({required this.authService})
      : db = AppDatabase(enableLogging: true),
        encryptionService = EncryptionService(),
        _authMiddleware = AuthMiddleware(authService),
        _rateLimitMiddleware = RateLimitMiddleware(authService) {
    db.init();
    categoryService = CategoryService(db);
    statusService = StatusService(db);
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

    // Link routes - require admin privileges
    router.post(
        '/links',
        Pipeline()
            .addMiddleware(_authMiddleware.requireAdmin)
            .addHandler(_handleCreateLink));

    router.put(
        '/links/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAdmin).addHandler(
            (request) => _handleUpdateLink(request, request.params['id']!)));

    router.delete(
        '/links/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAdmin).addHandler(
            (request) => _handleDeleteLink(request, request.params['id']!)));

    router.get(
        '/links/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAuth).addHandler(
            (request) => _handleGetLink(request, request.params['id']!)));

    // Category routes - require admin privileges
    router.get(
        '/categories/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAuth).addHandler(
            (request) =>
                _handleGetCategoryById(request, request.params['id']!)));

    router.post(
        '/categories',
        Pipeline()
            .addMiddleware(_authMiddleware.requireAdmin)
            .addHandler(_handleCreateCategory));

    router.put(
        '/categories/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAdmin).addHandler(
            (request) =>
                _handleUpdateCategory(request, request.params['id']!)));

    router.delete(
        '/categories/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAdmin).addHandler(
            (request) =>
                _handleDeleteCategory(request, request.params['id']!)));

    // Status routes
    router.get(
        '/statuses',
        Pipeline()
            .addMiddleware(_authMiddleware.requireAuth)
            .addHandler(_handleGetAllStatuses));

    router.get(
        '/statuses/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAuth).addHandler(
            (request) => _handleGetStatusById(request, request.params['id']!)));

    router.post(
        '/statuses',
        Pipeline()
            .addMiddleware(_authMiddleware.requireAdmin)
            .addHandler(_handleCreateStatus));

    router.put(
        '/statuses/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAdmin).addHandler(
            (request) => _handleUpdateStatus(request, request.params['id']!)));

    router.delete(
        '/statuses/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAdmin).addHandler(
            (request) => _handleDeleteStatus(request, request.params['id']!)));
    return router;
  }

  void dispose() {
    db.dispose();
  }

  /// Utility method to extract a list of integers from dynamic input
  List<int> _extractIntList(dynamic input) {
    if (input == null) {
      return [];
    }

    if (input is List) {
      return input
          .map((item) => item is int ? item : int.tryParse(item.toString()))
          .where((item) => item != null)
          .cast<int>()
          .toList();
    }

    return [];
  }

  Future<Response> _handleCreateCategory(Request request) async {
    final logger = LoggerFactory.getLogger('API');

    try {
      // Parse and validate the request body
      final payload = await request.readAsString();
      final data = InputSanitizer.sanitizeRequestBody(payload);

      if (data == null) {
        return ApiResponse.badRequest('Invalid request format');
      }

      // Validate required fields
      if (!data.containsKey('name')) {
        return ApiResponse.badRequest('Missing required field: name');
      }

      final name = data['name'];

      // Validate name
      if (name == null || (name is String && name.trim().isEmpty)) {
        return ApiResponse.badRequest('Category name cannot be empty');
      }

      // Create the category
      final id = await categoryService.createCategory(name);

      // Retrieve the created category for the response
      final createdCategory = await categoryService.getCategoryById(id);

      if (createdCategory == null) {
        return ApiResponse.serverError(
            'Category was created but could not be retrieved');
      }

      logger.info('Category created', {'id': id, 'name': name});
      return ApiResponse.ok({'success': true, 'category': createdCategory});
    } catch (e) {
      logger.error('Error creating category', e);
      return ApiResponse.serverError('Failed to create category',
          details: e.toString());
    }
  }

  Future<Response> _handleCreateLink(Request request) async {
    final logger = LoggerFactory.getLogger('API');

    try {
      // Parse and validate the request body
      final payload = await request.readAsString();
      final data = InputSanitizer.sanitizeRequestBody(payload);

      if (data == null) {
        return ApiResponse.badRequest('Invalid request format');
      }

      // Validate required fields
      final requiredFields = [
        'link',
        'title',
        'description',
        'statusId',
        'categoryId'
      ];
      final missingFields =
          requiredFields.where((field) => !data.containsKey(field)).toList();

      if (missingFields.isNotEmpty) {
        return ApiResponse.badRequest(
            'Missing required fields: ${missingFields.join(', ')}');
      }

      // Validate URL format
      if (!InputSanitizer.isValidUrl(data['link'])) {
        return ApiResponse.badRequest('Invalid URL format');
      }

      // Validate doc_link if provided
      if (data['docLink'] != null &&
          data['docLink'].toString().isNotEmpty &&
          !InputSanitizer.isValidUrl(data['docLink'])) {
        return ApiResponse.badRequest('Invalid documentation URL format');
      }

      // Extract and validate relationship IDs
      final viewIds = _extractIntList(data['viewIds']);
      final keywordIds = _extractIntList(data['keywordIds']);
      final managerIds = _extractIntList(data['managerIds']);

      // Create the link
      final id = await db.createLink(
        link: data['link'],
        title: data['title'],
        description: data['description'],
        docLink: data['docLink'],
        statusId: data['statusId'],
        categoryId: data['categoryId'],
        viewIds: viewIds,
        keywordIds: keywordIds,
        managerIds: managerIds,
      );

      // Retrieve the created link for the response
      final createdLink = db.getLinkById(id);

      if (createdLink == null) {
        return ApiResponse.serverError(
            'Link was created but could not be retrieved');
      }

      logger.info('Link created', {'id': id, 'title': data['title']});
      return ApiResponse.ok({'success': true, 'link': createdLink});
    } catch (e) {
      logger.error('Error creating link', e);
      return ApiResponse.serverError('Failed to create link',
          details: e.toString());
    }
  }

  Future<Response> _handleCreateStatus(Request request) async {
    final logger = LoggerFactory.getLogger('API');

    try {
      // Parse and validate the request body
      final payload = await request.readAsString();
      final data = InputSanitizer.sanitizeRequestBody(payload);

      if (data == null) {
        return ApiResponse.badRequest('Invalid request format');
      }

      // Validate required fields
      if (!data.containsKey('name')) {
        return ApiResponse.badRequest('Missing required field: name');
      }

      final name = data['name'];

      // Validate name
      if (name == null || (name is String && name.trim().isEmpty)) {
        return ApiResponse.badRequest('Status name cannot be empty');
      }

      // Create the status
      final id = await statusService.createStatus(name);

      // Retrieve the created status for the response
      final createdStatus = await statusService.getStatusById(id);

      if (createdStatus == null) {
        return ApiResponse.serverError(
            'Status was created but could not be retrieved');
      }

      logger.info('Status created', {'id': id, 'name': name});
      return ApiResponse.ok({'success': true, 'status': createdStatus});
    } catch (e, stackTrace) {
      logger.error('Error creating status', e, stackTrace);
      return ApiResponse.serverError('Failed to create status',
          details: e.toString());
    }
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

  Future<Response> _handleDeleteCategory(Request request, String id) async {
    final categoryId = int.tryParse(id);
    final logger = LoggerFactory.getLogger('API');

    if (categoryId == null) {
      return ApiResponse.badRequest('Invalid category ID');
    }

    try {
      // First check if the category exists and get its details for the response
      final category = await categoryService.getCategoryById(categoryId);

      if (category == null) {
        return ApiResponse.notFound('Category not found');
      }

      // Delete the category
      final success = await categoryService.deleteCategory(categoryId);

      if (!success) {
        return ApiResponse.serverError('Failed to delete category');
      }

      logger.info('Category deleted', {'id': categoryId});
      return ApiResponse.ok({'success': true, 'deletedCategory': category});
    } catch (e) {
      logger.error('Error deleting category', e, null, {'id': id});
      return ApiResponse.serverError('Failed to delete category',
          details: e.toString());
    }
  }

  Future<Response> _handleDeleteLink(Request request, String id) async {
    final logger = LoggerFactory.getLogger('API');
    final linkId = int.tryParse(id);

    if (linkId == null) {
      return ApiResponse.badRequest('Invalid link ID');
    }

    try {
      // First check if the link exists and get its details for the response
      final link = db.getLinkById(linkId);

      if (link == null) {
        return ApiResponse.notFound('Link not found');
      }

      // Delete the link
      final success = await db.deleteLink(linkId);

      if (!success) {
        return ApiResponse.serverError('Failed to delete link');
      }

      logger.info('Link deleted', {'id': linkId});
      return ApiResponse.ok({'success': true, 'deletedLink': link});
    } catch (e) {
      logger.error('Error deleting link', e, null, {'id': id});
      return ApiResponse.serverError('Failed to delete link',
          details: e.toString());
    }
  }

  Future<Response> _handleDeleteStatus(Request request, String id) async {
    final statusId = int.tryParse(id);
    final logger = LoggerFactory.getLogger('API');

    if (statusId == null) {
      return ApiResponse.badRequest('Invalid status ID');
    }

    try {
      // First check if the status exists and get its details for the response
      final status = await statusService.getStatusById(statusId);

      if (status == null) {
        return ApiResponse.notFound('Status not found');
      }

      // Delete the status
      final success = await statusService.deleteStatus(statusId);

      if (!success) {
        return ApiResponse.serverError('Failed to delete status');
      }

      logger.info('Status deleted', {'id': statusId});
      return ApiResponse.ok({'success': true, 'deletedStatus': status});
    } catch (e, stackTrace) {
      logger.error('Error deleting status', e, stackTrace, {'id': id});
      return ApiResponse.serverError('Failed to delete status',
          details: e.toString());
    }
  }

  Future<Response> _handleGetAllStatuses(Request request) async {
    final logger = LoggerFactory.getLogger('API');

    try {
      final statuses = statusService.getAllStatuses();
      return ApiResponse.ok({'statuses': statuses});
    } catch (e, stackTrace) {
      logger.error('Error retrieving all statuses', e, stackTrace);
      return ApiResponse.serverError('Failed to retrieve statuses',
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

  Future<Response> _handleGetCategoryById(Request request, String id) async {
    final categoryId = int.tryParse(id);
    final logger = LoggerFactory.getLogger('API');

    if (categoryId == null) {
      return ApiResponse.badRequest('Invalid category ID');
    }

    try {
      final category = await categoryService.getCategoryById(categoryId);

      if (category == null) {
        return ApiResponse.notFound('Category not found');
      }

      return ApiResponse.ok({'category': category});
    } catch (e) {
      logger.error('Error retrieving category', e, null, {'id': id});
      return ApiResponse.serverError('Failed to retrieve category',
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

  Future<Response> _handleGetLink(Request request, String id) async {
    final linkId = int.tryParse(id);

    if (linkId == null) {
      return ApiResponse.badRequest('Invalid link ID');
    }

    try {
      final link = db.getLinkById(linkId);

      if (link == null) {
        return ApiResponse.notFound('Link not found');
      }

      return ApiResponse.ok({'link': link});
    } catch (e) {
      final logger = LoggerFactory.getLogger('API');
      logger.error('Error retrieving link', e, null, {'id': id});
      return ApiResponse.serverError('Failed to retrieve link',
          details: e.toString());
    }
  }

  Future<Response> _handleGetPublicKey(Request request) async {
    return ApiResponse.ok({'publicKey': encryptionService.publicKey});
  }

  Future<Response> _handleGetStatusById(Request request, String id) async {
    final statusId = int.tryParse(id);
    final logger = LoggerFactory.getLogger('API');

    if (statusId == null) {
      return ApiResponse.badRequest('Invalid status ID');
    }

    try {
      final status = await statusService.getStatusById(statusId);

      if (status == null) {
        return ApiResponse.notFound('Status not found');
      }

      return ApiResponse.ok({'status': status});
    } catch (e, stackTrace) {
      logger.error('Error retrieving status', e, stackTrace, {'id': id});
      return ApiResponse.serverError('Failed to retrieve status',
          details: e.toString());
    }
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

  Future<Response> _handleUpdateCategory(Request request, String id) async {
    final categoryId = int.tryParse(id);
    final logger = LoggerFactory.getLogger('API');

    if (categoryId == null) {
      return ApiResponse.badRequest('Invalid category ID');
    }

    try {
      // Parse and validate the request body
      final payload = await request.readAsString();
      final data = InputSanitizer.sanitizeRequestBody(payload);

      if (data == null) {
        return ApiResponse.badRequest('Invalid request format');
      }

      // Validate required fields
      if (!data.containsKey('name')) {
        return ApiResponse.badRequest('Missing required field: name');
      }

      final name = data['name'];

      // Validate name
      if (name == null || (name is String && name.trim().isEmpty)) {
        return ApiResponse.badRequest('Category name cannot be empty');
      }

      // First check if the category exists
      final category = await categoryService.getCategoryById(categoryId);

      if (category == null) {
        return ApiResponse.notFound('Category not found');
      }

      // Update the category
      final success = await categoryService.updateCategory(categoryId, name);

      if (!success) {
        return ApiResponse.serverError('Failed to update category');
      }

      // Retrieve the updated category for the response
      final updatedCategory = await categoryService.getCategoryById(categoryId);

      logger.info('Category updated', {'id': categoryId, 'name': name});
      return ApiResponse.ok({'success': true, 'category': updatedCategory});
    } catch (e) {
      logger.error('Error updating category', e, null, {'id': id});
      return ApiResponse.serverError('Failed to update category',
          details: e.toString());
    }
  }

  Future<Response> _handleUpdateLink(Request request, String id) async {
    final logger = LoggerFactory.getLogger('API');
    final linkId = int.tryParse(id);

    if (linkId == null) {
      return ApiResponse.badRequest('Invalid link ID');
    }

    try {
      // Parse and validate the request body
      final payload = await request.readAsString();
      final data = InputSanitizer.sanitizeRequestBody(payload);

      if (data == null || data.isEmpty) {
        return ApiResponse.badRequest('Invalid or empty request');
      }

      // Validate URL format if provided
      if (data.containsKey('link') &&
          !InputSanitizer.isValidUrl(data['link'])) {
        return ApiResponse.badRequest('Invalid URL format');
      }

      // Validate doc_link if provided
      if (data.containsKey('docLink') &&
          data['docLink'] != null &&
          data['docLink'].toString().isNotEmpty &&
          !InputSanitizer.isValidUrl(data['docLink'])) {
        return ApiResponse.badRequest('Invalid documentation URL format');
      }

      // Extract relationship IDs if provided
      List<int>? viewIds;
      List<int>? keywordIds;
      List<int>? managerIds;

      if (data.containsKey('viewIds')) {
        viewIds = _extractIntList(data['viewIds']);
      }

      if (data.containsKey('keywordIds')) {
        keywordIds = _extractIntList(data['keywordIds']);
      }

      if (data.containsKey('managerIds')) {
        managerIds = _extractIntList(data['managerIds']);
      }

      // Update the link
      final success = await db.updateLink(
        id: linkId,
        link: data['link'],
        title: data['title'],
        description: data['description'],
        docLink: data['docLink'],
        statusId: data['statusId'],
        categoryId: data['categoryId'],
        viewIds: viewIds,
        keywordIds: keywordIds,
        managerIds: managerIds,
      );

      if (!success) {
        return ApiResponse.notFound('Link not found');
      }

      // Retrieve the updated link for the response
      final updatedLink = db.getLinkById(linkId);

      logger.info('Link updated', {'id': linkId});
      return ApiResponse.ok({'success': true, 'link': updatedLink});
    } catch (e) {
      logger.error('Error updating link', e, null, {'id': id});
      return ApiResponse.serverError('Failed to update link',
          details: e.toString());
    }
  }

  Future<Response> _handleUpdateStatus(Request request, String id) async {
    final statusId = int.tryParse(id);
    final logger = LoggerFactory.getLogger('API');

    if (statusId == null) {
      return ApiResponse.badRequest('Invalid status ID');
    }

    try {
      // Parse and validate the request body
      final payload = await request.readAsString();
      final data = InputSanitizer.sanitizeRequestBody(payload);

      if (data == null) {
        return ApiResponse.badRequest('Invalid request format');
      }

      // Validate required fields
      if (!data.containsKey('name')) {
        return ApiResponse.badRequest('Missing required field: name');
      }

      final name = data['name'];

      // Validate name
      if (name == null || (name is String && name.trim().isEmpty)) {
        return ApiResponse.badRequest('Status name cannot be empty');
      }

      // First check if the status exists
      final status = await statusService.getStatusById(statusId);

      if (status == null) {
        return ApiResponse.notFound('Status not found');
      }

      // Update the status
      final success = await statusService.updateStatus(statusId, name);

      if (!success) {
        return ApiResponse.serverError('Failed to update status');
      }

      // Retrieve the updated status for the response
      final updatedStatus = await statusService.getStatusById(statusId);

      logger.info('Status updated', {'id': statusId, 'name': name});
      return ApiResponse.ok({'success': true, 'status': updatedStatus});
    } catch (e, stackTrace) {
      logger.error('Error updating status', e, stackTrace, {'id': id});
      return ApiResponse.serverError('Failed to update status',
          details: e.toString());
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
