import 'package:backend/middleware/auth_middleware.dart';
import 'package:backend/services/input_sanitizer.dart';
import 'package:backend/services/view_service.dart';
import 'package:backend/utils/api_response.dart';
import 'package:backend/utils/logger.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class ViewController {
  final ViewService _viewService;
  final AuthMiddleware _authMiddleware;
  final Logger _logger = LoggerFactory.getLogger('ViewController');

  ViewController(this._viewService, this._authMiddleware);

  Router get router {
    final router = Router();

    router.get(
        '/',
        Pipeline()
            .addMiddleware(_authMiddleware.requireAuth)
            .addHandler(_handleGetAllViews));

    router.get(
        '/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAuth).addHandler(
            (request) => _handleGetViewById(request, request.params['id']!)));

    router.get(
        '/<id>/links',
        Pipeline().addMiddleware(_authMiddleware.requireAuth).addHandler(
            (request) =>
                _handleGetLinksByView(request, request.params['id']!)));

    router.post(
        '/',
        Pipeline()
            .addMiddleware(_authMiddleware.requireAdmin)
            .addHandler(_handleCreateView));

    router.put(
        '/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAdmin).addHandler(
            (request) => _handleUpdateView(request, request.params['id']!)));

    router.delete(
        '/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAdmin).addHandler(
            (request) => _handleDeleteView(request, request.params['id']!)));

    return router;
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
      final id = await _viewService.createView(name);

      // Retrieve the created view for the response
      final createdView = await _viewService.getViewById(id);

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

  Future<Response> _handleDeleteView(Request request, String id) async {
    final viewId = int.tryParse(id);

    if (viewId == null) {
      return ApiResponse.badRequest('Invalid view ID');
    }

    try {
      // First check if the view exists and get its details for the response
      final view = await _viewService.getViewById(viewId);

      if (view == null) {
        return ApiResponse.notFound('View not found');
      }

      // Delete the view
      final success = await _viewService.deleteView(viewId);

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

  Future<Response> _handleGetAllViews(Request request) async {
    try {
      final views = await _viewService.getAllViews();
      return ApiResponse.ok({'views': views});
    } catch (e, stackTrace) {
      _logger.error('Error retrieving all views', e, stackTrace);
      return ApiResponse.serverError('Failed to retrieve views',
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
      final view = await _viewService.getViewById(viewId);

      if (view == null) {
        return ApiResponse.notFound('View not found');
      }

      // Get links for this view
      final links = await _viewService.getLinksByViewId(viewId);

      return ApiResponse.ok(
          {'view': view, 'links': links, 'count': links.length});
    } catch (e, stackTrace) {
      _logger
          .error('Error retrieving links by view', e, stackTrace, {'id': id});
      return ApiResponse.serverError('Failed to retrieve links for view',
          details: e.toString());
    }
  }

  Future<Response> _handleGetViewById(Request request, String id) async {
    final viewId = int.tryParse(id);

    if (viewId == null) {
      return ApiResponse.badRequest('Invalid view ID');
    }

    try {
      final view = await _viewService.getViewById(viewId);

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
      final existingView = await _viewService.getViewById(viewId);

      if (existingView == null) {
        return ApiResponse.notFound('View not found');
      }

      // Update the view
      final success = await _viewService.updateView(viewId, name);

      if (!success) {
        return ApiResponse.serverError('Failed to update view');
      }

      // Retrieve the updated view for the response
      final updatedView = await _viewService.getViewById(viewId);

      _logger.info('View updated', {'id': viewId, 'name': name});
      return ApiResponse.ok({'success': true, 'view': updatedView});
    } catch (e, stackTrace) {
      _logger.error('Error updating view', e, stackTrace, {'id': id});
      return ApiResponse.serverError('Failed to update view',
          details: e.toString());
    }
  }
}
