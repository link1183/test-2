import 'package:backend/middleware/auth_middleware.dart';
import 'package:backend/services/input_sanitizer.dart';
import 'package:backend/services/link_service.dart';
import 'package:backend/utils/api_response.dart';
import 'package:backend/utils/logger.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class LinkController {
  final LinkService _linkService;
  final AuthMiddleware _authMiddleware;
  final Logger _logger = LoggerFactory.getLogger('LinkController');

  LinkController(this._linkService, this._authMiddleware);

  Router get router {
    final router = Router();

    router.get(
        '/',
        Pipeline()
            .addMiddleware(_authMiddleware.requireAuth)
            .addHandler(_handleGetAllLinks));

    router.post(
        '/',
        Pipeline()
            .addMiddleware(_authMiddleware.requireAdmin)
            .addHandler(_handleCreateLink));

    router.put(
        '/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAdmin).addHandler(
            (request) => _handleUpdateLink(request, request.params['id']!)));

    router.delete(
        '/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAdmin).addHandler(
            (request) => _handleDeleteLink(request, request.params['id']!)));

    router.get(
        '/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAuth).addHandler(
            (request) => _handleGetLink(request, request.params['id']!)));

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
      final id = await _linkService.createLink(
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
      final createdLink = await _linkService.getLinkById(id);

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

  Future<Response> _handleDeleteLink(Request request, String id) async {
    final linkId = int.tryParse(id);

    if (linkId == null) {
      return ApiResponse.badRequest('Invalid link ID');
    }

    try {
      // First check if the link exists and get its details for the response
      final link = await _linkService.getLinkById(linkId);

      if (link == null) {
        return ApiResponse.notFound('Link not found');
      }

      // Delete the link
      final success = await _linkService.deleteLink(linkId);

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

  Future<Response> _handleGetAllLinks(Request request) async {
    try {
      final links = await _linkService.getAllLinks();
      return ApiResponse.ok({'links': links});
    } catch (e, stackTrace) {
      _logger.error('Error retrieving all links', e, stackTrace);
      return ApiResponse.serverError('Failed to retrieve all links',
          details: e.toString());
    }
  }

  Future<Response> _handleGetLink(Request request, String id) async {
    final linkId = int.tryParse(id);

    if (linkId == null) {
      return ApiResponse.badRequest('Invalid link ID');
    }

    try {
      final link = await _linkService.getLinkById(linkId);

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
      final success = await _linkService.updateLink(
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
      final updatedLink = await _linkService.getLinkById(linkId);

      _logger.info('Link updated', {'id': linkId});
      return ApiResponse.ok({'success': true, 'link': updatedLink});
    } catch (e) {
      _logger.error('Error updating link', e, null, {'id': id});
      return ApiResponse.serverError('Failed to update link',
          details: e.toString());
    }
  }
}
