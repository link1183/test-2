import 'dart:convert';

import 'package:backend/db/database_connection_pool.dart';
import 'package:backend/middleware/auth_middleware.dart';
import 'package:backend/middleware/rate_limit_middleware.dart';
import 'package:backend/services/auth_service.dart';
import 'package:backend/services/category_service.dart';
import 'package:backend/services/encryption_service.dart';
import 'package:backend/services/input_sanitizer.dart';
import 'package:backend/services/keyword_service.dart';
import 'package:backend/services/link_manager_service.dart';
import 'package:backend/services/link_service.dart';
import 'package:backend/services/status_service.dart';
import 'package:backend/services/view_service.dart';
import 'package:backend/utils/api_response.dart';
import 'package:backend/utils/logger.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class Api {
  final DatabaseConnectionPool _connectionPool;
  final AuthService authService;
  final EncryptionService encryptionService;
  final AuthMiddleware _authMiddleware;
  final RateLimitMiddleware _rateLimitMiddleware;
  late final CategoryService categoryService;
  late final StatusService statusService;
  late final KeywordService keywordService;
  late final ViewService viewService;
  late final LinkManagerService managerService;
  late final LinkService linkService;
  final _logger = LoggerFactory.getLogger('API');

  Api({
    required this.authService,
    required DatabaseConnectionPool connectionPool,
  })  : _connectionPool = connectionPool,
        encryptionService = EncryptionService(),
        _authMiddleware = AuthMiddleware(authService),
        _rateLimitMiddleware = RateLimitMiddleware(authService) {
    categoryService = CategoryService(_connectionPool);
    statusService = StatusService(_connectionPool);
    keywordService = KeywordService(_connectionPool);
    viewService = ViewService(_connectionPool);
    managerService = LinkManagerService(_connectionPool);
    linkService = LinkService(_connectionPool);
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
    //router.get(
    //    '/admin/db-stats',
    //    Pipeline()
    //        .addMiddleware(_authMiddleware.requireAdmin)
    //        .addHandler(_handleGetDbStats));

    //router.post(
    //    '/admin/db-backup',
    //    Pipeline()
    //        .addMiddleware(_authMiddleware.requireAdmin)
    //        .addHandler(_handleDbBackup));

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

    // Keyword routes
    router.get(
        '/keywords',
        Pipeline()
            .addMiddleware(_authMiddleware.requireAuth)
            .addHandler(_handleGetAllKeywords));

    router.get(
        '/keywords/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAuth).addHandler(
            (request) =>
                _handleGetKeywordById(request, request.params['id']!)));

    router.get(
        '/keywords/<id>/links',
        Pipeline().addMiddleware(_authMiddleware.requireAuth).addHandler(
            (request) =>
                _handleGetLinksByKeyword(request, request.params['id']!)));

    router.post(
        '/keywords',
        Pipeline()
            .addMiddleware(_authMiddleware.requireAdmin)
            .addHandler(_handleCreateKeyword));

    router.put(
        '/keywords/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAdmin).addHandler(
            (request) => _handleUpdateKeyword(request, request.params['id']!)));

    router.delete(
        '/keywords/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAdmin).addHandler(
            (request) => _handleDeleteKeyword(request, request.params['id']!)));

    // View routes
    router.get(
        '/views',
        Pipeline()
            .addMiddleware(_authMiddleware.requireAuth)
            .addHandler(_handleGetAllViews));

    router.get(
        '/views/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAuth).addHandler(
            (request) => _handleGetViewById(request, request.params['id']!)));

    router.get(
        '/views/<id>/links',
        Pipeline().addMiddleware(_authMiddleware.requireAuth).addHandler(
            (request) =>
                _handleGetLinksByView(request, request.params['id']!)));

    router.post(
        '/views',
        Pipeline()
            .addMiddleware(_authMiddleware.requireAdmin)
            .addHandler(_handleCreateView));

    router.put(
        '/views/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAdmin).addHandler(
            (request) => _handleUpdateView(request, request.params['id']!)));

    router.delete(
        '/views/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAdmin).addHandler(
            (request) => _handleDeleteView(request, request.params['id']!)));

    // Link Manager routes
    router.get(
        '/managers',
        Pipeline()
            .addMiddleware(_authMiddleware.requireAuth)
            .addHandler(_handleGetAllManagers));

    router.get(
        '/managers/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAuth).addHandler(
            (request) =>
                _handleGetManagerById(request, request.params['id']!)));

    router.get(
        '/managers/<id>/links',
        Pipeline().addMiddleware(_authMiddleware.requireAuth).addHandler(
            (request) =>
                _handleGetLinksByManager(request, request.params['id']!)));

    router.post(
        '/managers',
        Pipeline()
            .addMiddleware(_authMiddleware.requireAdmin)
            .addHandler(_handleCreateManager));

    router.put(
        '/managers/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAdmin).addHandler(
            (request) => _handleUpdateManager(request, request.params['id']!)));

    router.delete(
        '/managers/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAdmin).addHandler(
            (request) => _handleDeleteManager(request, request.params['id']!)));

    return router;
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

      _logger.info('Category created', {'id': id, 'name': name});
      return ApiResponse.ok({'success': true, 'category': createdCategory});
    } catch (e) {
      _logger.error('Error creating category', e);
      return ApiResponse.serverError('Failed to create category',
          details: e.toString());
    }
  }

  Future<Response> _handleCreateKeyword(Request request) async {
    try {
      // Parse and validate the request body
      final payload = await request.readAsString();
      final data = InputSanitizer.sanitizeRequestBody(payload);

      if (data == null) {
        return ApiResponse.badRequest('Invalid request format');
      }

      // Validate required fields
      if (!data.containsKey('keyword')) {
        return ApiResponse.badRequest('Missing required field: keyword');
      }

      final keyword = data['keyword'];

      // Validate keyword
      if (keyword == null || (keyword is String && keyword.trim().isEmpty)) {
        return ApiResponse.badRequest('Keyword cannot be empty');
      }

      // Create the keyword
      final id = await keywordService.createKeyword(keyword);

      // Retrieve the created keyword for the response
      final createdKeyword = await keywordService.getKeywordById(id);

      if (createdKeyword == null) {
        return ApiResponse.serverError(
            'Keyword was created but could not be retrieved');
      }

      _logger.info('Keyword created', {'id': id, 'keyword': keyword});
      return ApiResponse.ok({'success': true, 'keyword': createdKeyword});
    } catch (e, stackTrace) {
      _logger.error('Error creating keyword', e, stackTrace);
      return ApiResponse.serverError('Failed to create keyword',
          details: e.toString());
    }
  }

  Future<Response> _handleCreateLink(Request request) async {
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
      final id = await linkService.createLink(
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
      final createdLink = await linkService.getLinkById(id);

      if (createdLink == null) {
        return ApiResponse.serverError(
            'Link was created but could not be retrieved');
      }

      _logger.info('Link created', {'id': id, 'title': data['title']});
      return ApiResponse.ok({'success': true, 'link': createdLink});
    } catch (e) {
      _logger.error('Error creating link', e);
      return ApiResponse.serverError('Failed to create link',
          details: e.toString());
    }
  }

  /// Handler for POST /api/managers - Creates a new link manager
  Future<Response> _handleCreateManager(Request request) async {
    try {
      // Parse and validate the request body
      final payload = await request.readAsString();
      final data = InputSanitizer.sanitizeRequestBody(payload);

      if (data == null) {
        return ApiResponse.badRequest('Invalid request format');
      }

      // Validate required fields
      if (!data.containsKey('name') || !data.containsKey('surname')) {
        return ApiResponse.badRequest(
            'Missing required fields: name and surname are required');
      }

      final name = data['name'];
      final surname = data['surname'];
      final link = data['link'] as String?;

      // Validate name and surname
      if (name == null || (name is String && name.trim().isEmpty)) {
        return ApiResponse.badRequest('Manager name cannot be empty');
      }

      if (surname == null || (surname is String && surname.trim().isEmpty)) {
        return ApiResponse.badRequest('Manager surname cannot be empty');
      }

      // Validate link if provided
      if (link != null && link.isNotEmpty) {
        if (!InputSanitizer.isValidUrl(link)) {
          return ApiResponse.badRequest('Invalid URL format for link');
        }
      }

      // Create the link manager
      final id = await managerService.createLinkManager(name, surname, link);

      // Retrieve the created link manager for the response
      final createdManager = await managerService.getLinkManagerById(id);

      if (createdManager == null) {
        return ApiResponse.serverError(
            'Link manager was created but could not be retrieved');
      }

      _logger
          .info('Link manager created', {'id': id, 'name': '$name $surname'});
      return ApiResponse.ok({'success': true, 'manager': createdManager});
    } catch (e, stackTrace) {
      _logger.error('Error creating link manager', e, stackTrace);
      return ApiResponse.serverError('Failed to create link manager',
          details: e.toString());
    }
  }

  Future<Response> _handleCreateStatus(Request request) async {
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

      _logger.info('Status created', {'id': id, 'name': name});
      return ApiResponse.ok({'success': true, 'status': createdStatus});
    } catch (e, stackTrace) {
      _logger.error('Error creating status', e, stackTrace);
      return ApiResponse.serverError('Failed to create status',
          details: e.toString());
    }
  }

  /// Handler for POST /api/views - Creates a new view
  Future<Response> _handleCreateView(Request request) async {
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
        return ApiResponse.badRequest('View name cannot be empty');
      }

      // Create the view
      final id = await viewService.createView(name);

      // Retrieve the created view for the response
      final createdView = await viewService.getViewById(id);

      if (createdView == null) {
        return ApiResponse.serverError(
            'View was created but could not be retrieved');
      }

      _logger.info('View created', {'id': id, 'name': name});
      return ApiResponse.ok({'success': true, 'view': createdView});
    } catch (e, stackTrace) {
      _logger.error('Error creating view', e, stackTrace);
      return ApiResponse.serverError('Failed to create view',
          details: e.toString());
    }
  }

  //Future<Response> _handleDbBackup(Request request) async {
  //  try {
  //    final timestamp = DateTime.now()
  //        .toIso8601String()
  //        .replaceAll(':', '-')
  //        .replaceAll('.', '-');
  //    final backupPath = '/data/backup_$timestamp.db';
  //
  //    final success = await _connectionPool.backup(backupPath);
  //
  //    if (success) {
  //      return ApiResponse.ok({'success': true, 'path': backupPath});
  //    } else {
  //      return ApiResponse.serverError('Backup failed');
  //    }
  //  } catch (e) {
  //    return ApiResponse.serverError('Error creating database backup',
  //        details: e.toString());
  //  }
  //}

  Future<Response> _handleDeleteCategory(Request request, String id) async {
    final categoryId = int.tryParse(id);

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

      _logger.info('Category deleted', {'id': categoryId});
      return ApiResponse.ok({'success': true, 'deletedCategory': category});
    } catch (e) {
      _logger.error('Error deleting category', e, null, {'id': id});
      return ApiResponse.serverError('Failed to delete category',
          details: e.toString());
    }
  }

  Future<Response> _handleDeleteKeyword(Request request, String id) async {
    final keywordId = int.tryParse(id);

    if (keywordId == null) {
      return ApiResponse.badRequest('Invalid keyword ID');
    }

    try {
      // First check if the keyword exists and get its details for the response
      final keyword = await keywordService.getKeywordById(keywordId);

      if (keyword == null) {
        return ApiResponse.notFound('Keyword not found');
      }

      // Delete the keyword
      final success = await keywordService.deleteKeyword(keywordId);

      if (!success) {
        return ApiResponse.serverError('Failed to delete keyword');
      }

      _logger.info('Keyword deleted', {'id': keywordId});
      return ApiResponse.ok({'success': true, 'deletedKeyword': keyword});
    } catch (e, stackTrace) {
      _logger.error('Error deleting keyword', e, stackTrace, {'id': id});
      return ApiResponse.serverError('Failed to delete keyword',
          details: e.toString());
    }
  }

  Future<Response> _handleDeleteLink(Request request, String id) async {
    final linkId = int.tryParse(id);

    if (linkId == null) {
      return ApiResponse.badRequest('Invalid link ID');
    }

    try {
      // First check if the link exists and get its details for the response
      final link = await linkService.getLinkById(linkId);

      if (link == null) {
        return ApiResponse.notFound('Link not found');
      }

      // Delete the link
      final success = await linkService.deleteLink(linkId);

      if (!success) {
        return ApiResponse.serverError('Failed to delete link');
      }

      _logger.info('Link deleted', {'id': linkId});
      return ApiResponse.ok({'success': true, 'deletedLink': link});
    } catch (e) {
      _logger.error('Error deleting link', e, null, {'id': id});
      return ApiResponse.serverError('Failed to delete link',
          details: e.toString());
    }
  }

  Future<Response> _handleDeleteManager(Request request, String id) async {
    final managerId = int.tryParse(id);

    if (managerId == null) {
      return ApiResponse.badRequest('Invalid link manager ID');
    }

    try {
      // First check if the link manager exists and get its details for the response
      final manager = await managerService.getLinkManagerById(managerId);

      if (manager == null) {
        return ApiResponse.notFound('Link manager not found');
      }

      // Delete the link manager
      final success = await managerService.deleteLinkManager(managerId);

      if (!success) {
        return ApiResponse.serverError('Failed to delete link manager');
      }

      _logger.info('Link manager deleted', {'id': managerId});
      return ApiResponse.ok({'success': true, 'deletedManager': manager});
    } catch (e, stackTrace) {
      _logger.error('Error deleting link manager', e, stackTrace, {'id': id});
      return ApiResponse.serverError('Failed to delete link manager',
          details: e.toString());
    }
  }

  Future<Response> _handleDeleteStatus(Request request, String id) async {
    final statusId = int.tryParse(id);

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

      _logger.info('Status deleted', {'id': statusId});
      return ApiResponse.ok({'success': true, 'deletedStatus': status});
    } catch (e, stackTrace) {
      _logger.error('Error deleting status', e, stackTrace, {'id': id});
      return ApiResponse.serverError('Failed to delete status',
          details: e.toString());
    }
  }

  Future<Response> _handleDeleteView(Request request, String id) async {
    final viewId = int.tryParse(id);

    if (viewId == null) {
      return ApiResponse.badRequest('Invalid view ID');
    }

    try {
      // First check if the view exists and get its details for the response
      final view = await viewService.getViewById(viewId);

      if (view == null) {
        return ApiResponse.notFound('View not found');
      }

      // Delete the view
      final success = await viewService.deleteView(viewId);

      if (!success) {
        return ApiResponse.serverError('Failed to delete view');
      }

      _logger.info('View deleted', {'id': viewId});
      return ApiResponse.ok({'success': true, 'deletedView': view});
    } catch (e, stackTrace) {
      _logger.error('Error deleting view', e, stackTrace, {'id': id});
      return ApiResponse.serverError('Failed to delete view',
          details: e.toString());
    }
  }

  Future<Response> _handleGetAllKeywords(Request request) async {
    try {
      final keywords = keywordService.getAllKeywords();
      return ApiResponse.ok({'keywords': keywords});
    } catch (e, stackTrace) {
      _logger.error('Error retrieving all keywords', e, stackTrace);
      return ApiResponse.serverError('Failed to retrieve keywords',
          details: e.toString());
    }
  }

  Future<Response> _handleGetAllManagers(Request request) async {
    try {
      final managers = managerService.getAllLinkManagers();
      return ApiResponse.ok({'managers': managers});
    } catch (e, stackTrace) {
      _logger.error('Error retrieving all link managers', e, stackTrace);
      return ApiResponse.serverError('Failed to retrieve link managers',
          details: e.toString());
    }
  }

  Future<Response> _handleGetAllStatuses(Request request) async {
    try {
      final statuses = statusService.getAllStatuses();
      return ApiResponse.ok({'statuses': statuses});
    } catch (e, stackTrace) {
      _logger.error('Error retrieving all statuses', e, stackTrace);
      return ApiResponse.serverError('Failed to retrieve statuses',
          details: e.toString());
    }
  }

  Future<Response> _handleGetAllViews(Request request) async {
    try {
      final views = viewService.getAllViews();
      return ApiResponse.ok({'views': views});
    } catch (e, stackTrace) {
      _logger.error('Error retrieving all views', e, stackTrace);
      return ApiResponse.serverError('Failed to retrieve views',
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
      _logger.error('Error retrieving category', e, null, {'id': id});
      return ApiResponse.serverError('Failed to retrieve category',
          details: e.toString());
    }
  }

  //Future<Response> _handleGetDbStats(Request request) async {
  //  try {
  //    final stats = _connectionPool.getDatabaseStats();
  //    return ApiResponse.ok({'stats': stats});
  //  } catch (e) {
  //    return ApiResponse.serverError('Error retrieving database statistics',
  //        details: e.toString());
  //  }
  //}

  Future<Response> _handleGetKeywordById(Request request, String id) async {
    final keywordId = int.tryParse(id);

    if (keywordId == null) {
      return ApiResponse.badRequest('Invalid keyword ID');
    }

    try {
      final keyword = await keywordService.getKeywordById(keywordId);

      if (keyword == null) {
        return ApiResponse.notFound('Keyword not found');
      }

      return ApiResponse.ok({'keyword': keyword});
    } catch (e, stackTrace) {
      _logger.error('Error retrieving keyword', e, stackTrace, {'id': id});
      return ApiResponse.serverError('Failed to retrieve keyword',
          details: e.toString());
    }
  }

  Future<Response> _handleGetLink(Request request, String id) async {
    final linkId = int.tryParse(id);

    if (linkId == null) {
      return ApiResponse.badRequest('Invalid link ID');
    }

    try {
      final link = await linkService.getLinkById(linkId);

      if (link == null) {
        return ApiResponse.notFound('Link not found');
      }

      return ApiResponse.ok({'link': link});
    } catch (e) {
      _logger.error('Error retrieving link', e, null, {'id': id});
      return ApiResponse.serverError('Failed to retrieve link',
          details: e.toString());
    }
  }

  /// Handle GET /api/keywords/{id}/links
  Future<Response> _handleGetLinksByKeyword(Request request, String id) async {
    final keywordId = int.tryParse(id);

    if (keywordId == null) {
      return ApiResponse.badRequest('Invalid keyword ID');
    }

    try {
      // First check if the keyword exists
      final keyword = await keywordService.getKeywordById(keywordId);

      if (keyword == null) {
        return ApiResponse.notFound('Keyword not found');
      }

      // Get links for this keyword
      final links = await keywordService.getLinksByKeywordId(keywordId);

      return ApiResponse.ok(
          {'keyword': keyword.toMap(), 'links': links, 'count': links.length});
    } catch (e, stackTrace) {
      _logger.error(
          'Error retrieving links by keyword', e, stackTrace, {'id': id});
      return ApiResponse.serverError('Failed to retrieve links for keyword',
          details: e.toString());
    }
  }

  Future<Response> _handleGetLinksByManager(Request request, String id) async {
    final managerId = int.tryParse(id);

    if (managerId == null) {
      return ApiResponse.badRequest('Invalid link manager ID');
    }

    try {
      // First check if the link manager exists
      final manager = await managerService.getLinkManagerById(managerId);

      if (manager == null) {
        return ApiResponse.notFound('Link manager not found');
      }

      // Get links for this manager
      final links = await managerService.getLinksByManagerId(managerId);

      return ApiResponse.ok(
          {'manager': manager, 'links': links, 'count': links.length});
    } catch (e, stackTrace) {
      _logger.error(
          'Error retrieving links by manager', e, stackTrace, {'id': id});
      return ApiResponse.serverError('Failed to retrieve links for manager',
          details: e.toString());
    }
  }

  Future<Response> _handleGetLinksByView(Request request, String id) async {
    final viewId = int.tryParse(id);

    if (viewId == null) {
      return ApiResponse.badRequest('Invalid view ID');
    }

    try {
      // First check if the view exists
      final view = await viewService.getViewById(viewId);

      if (view == null) {
        return ApiResponse.notFound('View not found');
      }

      // Get links for this view
      final links = await viewService.getLinksByViewId(viewId);

      return ApiResponse.ok(
          {'view': view, 'links': links, 'count': links.length});
    } catch (e, stackTrace) {
      _logger
          .error('Error retrieving links by view', e, stackTrace, {'id': id});
      return ApiResponse.serverError('Failed to retrieve links for view',
          details: e.toString());
    }
  }

  Future<Response> _handleGetManagerById(Request request, String id) async {
    final managerId = int.tryParse(id);

    if (managerId == null) {
      return ApiResponse.badRequest('Invalid link manager ID');
    }

    try {
      final manager = await managerService.getLinkManagerById(managerId);

      if (manager == null) {
        return ApiResponse.notFound('Link manager not found');
      }

      return ApiResponse.ok({'manager': manager});
    } catch (e, stackTrace) {
      _logger.error('Error retrieving link manager', e, stackTrace, {'id': id});
      return ApiResponse.serverError('Failed to retrieve link manager',
          details: e.toString());
    }
  }

  Future<Response> _handleGetPublicKey(Request request) async {
    return ApiResponse.ok({'publicKey': encryptionService.publicKey});
  }

  Future<Response> _handleGetStatusById(Request request, String id) async {
    final statusId = int.tryParse(id);

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
      _logger.error('Error retrieving status', e, stackTrace, {'id': id});
      return ApiResponse.serverError('Failed to retrieve status',
          details: e.toString());
    }
  }

  Future<Response> _handleGetViewById(Request request, String id) async {
    final viewId = int.tryParse(id);

    if (viewId == null) {
      return ApiResponse.badRequest('Invalid view ID');
    }

    try {
      final view = await viewService.getViewById(viewId);

      if (view == null) {
        return ApiResponse.notFound('View not found');
      }

      return ApiResponse.ok({'view': view});
    } catch (e, stackTrace) {
      _logger.error('Error retrieving view', e, stackTrace, {'id': id});
      return ApiResponse.serverError('Failed to retrieve view',
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

      _logger.info('Category updated', {'id': categoryId, 'name': name});
      return ApiResponse.ok({'success': true, 'category': updatedCategory});
    } catch (e) {
      _logger.error('Error updating category', e, null, {'id': id});
      return ApiResponse.serverError('Failed to update category',
          details: e.toString());
    }
  }

  Future<Response> _handleUpdateKeyword(Request request, String id) async {
    final keywordId = int.tryParse(id);

    if (keywordId == null) {
      return ApiResponse.badRequest('Invalid keyword ID');
    }

    try {
      // Parse and validate the request body
      final payload = await request.readAsString();
      final data = InputSanitizer.sanitizeRequestBody(payload);

      if (data == null) {
        return ApiResponse.badRequest('Invalid request format');
      }

      // Validate required fields
      if (!data.containsKey('keyword')) {
        return ApiResponse.badRequest('Missing required field: keyword');
      }

      final keyword = data['keyword'];

      // Validate keyword
      if (keyword == null || (keyword is String && keyword.trim().isEmpty)) {
        return ApiResponse.badRequest('Keyword cannot be empty');
      }

      // First check if the keyword exists
      final existingKeyword = await keywordService.getKeywordById(keywordId);

      if (existingKeyword == null) {
        return ApiResponse.notFound('Keyword not found');
      }

      // Update the keyword
      final success = await keywordService.updateKeyword(keywordId, keyword);

      if (!success) {
        return ApiResponse.serverError('Failed to update keyword');
      }

      // Retrieve the updated keyword for the response
      final updatedKeyword = keywordService.getKeywordById(keywordId);

      _logger.info('Keyword updated', {'id': keywordId, 'keyword': keyword});
      return ApiResponse.ok({'success': true, 'keyword': updatedKeyword});
    } catch (e, stackTrace) {
      _logger.error('Error updating keyword', e, stackTrace, {'id': id});
      return ApiResponse.serverError('Failed to update keyword',
          details: e.toString());
    }
  }

  Future<Response> _handleUpdateLink(Request request, String id) async {
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
      final success = await linkService.updateLink(
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
      final updatedLink = await linkService.getLinkById(linkId);

      _logger.info('Link updated', {'id': linkId});
      return ApiResponse.ok({'success': true, 'link': updatedLink});
    } catch (e) {
      _logger.error('Error updating link', e, null, {'id': id});
      return ApiResponse.serverError('Failed to update link',
          details: e.toString());
    }
  }

  Future<Response> _handleUpdateManager(Request request, String id) async {
    final managerId = int.tryParse(id);

    if (managerId == null) {
      return ApiResponse.badRequest('Invalid link manager ID');
    }

    try {
      // Parse and validate the request body
      final payload = await request.readAsString();
      final data = InputSanitizer.sanitizeRequestBody(payload);

      if (data == null || data.isEmpty) {
        return ApiResponse.badRequest('Invalid request format or empty data');
      }

      // Extract fields that can be updated
      final name = data['name'] as String?;
      final surname = data['surname'] as String?;
      final link = data['link'] as String?;

      // Validate fields if provided
      if (name != null && name.trim().isEmpty) {
        return ApiResponse.badRequest('Manager name cannot be empty');
      }

      if (surname != null && surname.trim().isEmpty) {
        return ApiResponse.badRequest('Manager surname cannot be empty');
      }

      // Validate link if provided
      if (link != null && link.isNotEmpty) {
        if (!InputSanitizer.isValidUrl(link)) {
          return ApiResponse.badRequest('Invalid URL format for link');
        }
      }

      // First check if the link manager exists
      final existingManager =
          await managerService.getLinkManagerById(managerId);

      if (existingManager == null) {
        return ApiResponse.notFound('Link manager not found');
      }

      // Update the link manager
      final success = await managerService.updateLinkManager(managerId,
          name: name, surname: surname, link: link);

      if (!success) {
        return ApiResponse.serverError('Failed to update link manager');
      }

      // Retrieve the updated link manager for the response
      final updatedManager = managerService.getLinkManagerById(managerId);

      _logger.info('Link manager updated', {'id': managerId});
      return ApiResponse.ok({'success': true, 'manager': updatedManager});
    } catch (e, stackTrace) {
      _logger.error('Error updating link manager', e, stackTrace, {'id': id});
      return ApiResponse.serverError('Failed to update link manager',
          details: e.toString());
    }
  }

  Future<Response> _handleUpdateStatus(Request request, String id) async {
    final statusId = int.tryParse(id);

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

      _logger.info('Status updated', {'id': statusId, 'name': name});
      return ApiResponse.ok({'success': true, 'status': updatedStatus});
    } catch (e, stackTrace) {
      _logger.error('Error updating status', e, stackTrace, {'id': id});
      return ApiResponse.serverError('Failed to update status',
          details: e.toString());
    }
  }

  Future<Response> _handleUpdateView(Request request, String id) async {
    final viewId = int.tryParse(id);

    if (viewId == null) {
      return ApiResponse.badRequest('Invalid view ID');
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
        return ApiResponse.badRequest('View name cannot be empty');
      }

      // First check if the view exists
      final existingView = await viewService.getViewById(viewId);

      if (existingView == null) {
        return ApiResponse.notFound('View not found');
      }

      // Update the view
      final success = await viewService.updateView(viewId, name);

      if (!success) {
        return ApiResponse.serverError('Failed to update view');
      }

      // Retrieve the updated view for the response
      final updatedView = viewService.getViewById(viewId);

      _logger.info('View updated', {'id': viewId, 'name': name});
      return ApiResponse.ok({'success': true, 'view': updatedView});
    } catch (e, stackTrace) {
      _logger.error('Error updating view', e, stackTrace, {'id': id});
      return ApiResponse.serverError('Failed to update view',
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
