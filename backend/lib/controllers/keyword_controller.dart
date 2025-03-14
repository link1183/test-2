import 'package:backend/middleware/auth_middleware.dart';
import 'package:backend/services/input_sanitizer.dart';
import 'package:backend/services/keyword_service.dart';
import 'package:backend/utils/api_response.dart';
import 'package:backend/utils/logger.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Controller that handles all category-related API endpoints.
class KeywordController {
  final KeywordService _keywordService;
  final AuthMiddleware _authMiddleware;
  final Logger _logger = LoggerFactory.getLogger('KeywordController');

  KeywordController(this._keywordService, this._authMiddleware);

  /// Returns the router with all category routes defined.
  Router get router {
    final router = Router();

    // Get all keywords - requires authentification
    router.get(
        '/',
        Pipeline()
            .addMiddleware(_authMiddleware.requireAuth)
            .addHandler(_handleGetAllKeywords));

    // Get keyword by ID - requires authentification
    router.get(
        '/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAuth).addHandler(
            (request) =>
                _handleGetKeywordById(request, request.params['id']!)));

    // Get links by keyword ID - requires authentification
    router.get(
        '/<id>/links',
        Pipeline().addMiddleware(_authMiddleware.requireAuth).addHandler(
            (request) =>
                _handleGetLinksByKeyword(request, request.params['id']!)));

    // Create keyword - requires admin privileges
    router.post(
        '/',
        Pipeline()
            .addMiddleware(_authMiddleware.requireAdmin)
            .addHandler(_handleCreateKeyword));

    // Update keyword - requires admin privileges
    router.put(
        '/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAdmin).addHandler(
            (request) => _handleUpdateKeyword(request, request.params['id']!)));

    // Delete keyword - requires admin privileges
    router.delete(
        '/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAdmin).addHandler(
            (request) => _handleDeleteKeyword(request, request.params['id']!)));

    return router;
  }

  /// Handler for POST /api/keywords
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
      final id = await _keywordService.createKeyword(keyword);

      // Retrieve the created keyword for the response
      final createdKeyword = await _keywordService.getKeywordById(id);

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

  /// Handler for DELETE /api/keywords/:id
  Future<Response> _handleDeleteKeyword(Request request, String id) async {
    final keywordId = int.tryParse(id);

    if (keywordId == null) {
      return ApiResponse.badRequest('Invalid keyword ID');
    }

    try {
      // First check if the keyword exists and get its details for the response
      final keyword = await _keywordService.getKeywordById(keywordId);

      if (keyword == null) {
        return ApiResponse.notFound('Keyword not found');
      }

      // Delete the keyword
      final success = await _keywordService.deleteKeyword(keywordId);

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

  /// Handler for GET /api/keywords
  Future<Response> _handleGetAllKeywords(Request request) async {
    try {
      final keywords = await _keywordService.getAllKeywords();
      return ApiResponse.ok({'keywords': keywords});
    } catch (e, stackTrace) {
      _logger.error('Error retrieving all keywords', e, stackTrace);
      return ApiResponse.serverError('Failed to retrieve keywords',
          details: e.toString());
    }
  }

  /// Handler for GET /api/keywords/:id
  Future<Response> _handleGetKeywordById(Request request, String id) async {
    final keywordId = int.tryParse(id);

    if (keywordId == null) {
      return ApiResponse.badRequest('Invalid keyword ID');
    }

    try {
      final keyword = await _keywordService.getKeywordById(keywordId);

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

  /// Handler for GET /api/keywords/:id/links
  Future<Response> _handleGetLinksByKeyword(Request request, String id) async {
    final keywordId = int.tryParse(id);

    if (keywordId == null) {
      return ApiResponse.badRequest('Invalid keyword ID');
    }

    try {
      // First check if the keyword exists
      final keyword = await _keywordService.getKeywordById(keywordId);

      if (keyword == null) {
        return ApiResponse.notFound('Keyword not found');
      }

      // Get links for this keyword
      final links = await _keywordService.getLinksByKeywordId(keywordId);

      return ApiResponse.ok(
          {'keyword': keyword.toMap(), 'links': links, 'count': links.length});
    } catch (e, stackTrace) {
      _logger.error(
          'Error retrieving links by keyword', e, stackTrace, {'id': id});
      return ApiResponse.serverError('Failed to retrieve links for keyword',
          details: e.toString());
    }
  }

  /// Handler for PUT /api/keywords/:id
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
      final existingKeyword = await _keywordService.getKeywordById(keywordId);

      if (existingKeyword == null) {
        return ApiResponse.notFound('Keyword not found');
      }

      // Update the keyword
      final success = await _keywordService.updateKeyword(keywordId, keyword);

      if (!success) {
        return ApiResponse.serverError('Failed to update keyword');
      }

      // Retrieve the updated keyword for the response
      final updatedKeyword = await _keywordService.getKeywordById(keywordId);

      _logger.info('Keyword updated', {'id': keywordId, 'keyword': keyword});
      return ApiResponse.ok({'success': true, 'keyword': updatedKeyword});
    } catch (e, stackTrace) {
      _logger.error('Error updating keyword', e, stackTrace, {'id': id});
      return ApiResponse.serverError('Failed to update keyword',
          details: e.toString());
    }
  }
}
