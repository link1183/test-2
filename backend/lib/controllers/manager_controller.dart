import 'package:backend/middleware/auth_middleware.dart';
import 'package:backend/services/input_sanitizer.dart';
import 'package:backend/services/link_manager_service.dart';
import 'package:backend/utils/api_response.dart';
import 'package:backend/utils/logger.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class ManagerController {
  final LinkManagerService _managerService;
  final AuthMiddleware _authMiddleware;
  final Logger _logger = LoggerFactory.getLogger('ManagerController');

  ManagerController(this._managerService, this._authMiddleware);

  Router get router {
    final router = Router();

    router.get(
        '/',
        Pipeline()
            .addMiddleware(_authMiddleware.requireAuth)
            .addHandler(_handleGetAllManagers));

    router.get(
        '/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAuth).addHandler(
            (request) =>
                _handleGetManagerById(request, request.params['id']!)));

    router.get(
        '/<id>/links',
        Pipeline().addMiddleware(_authMiddleware.requireAuth).addHandler(
            (request) =>
                _handleGetLinksByManager(request, request.params['id']!)));

    router.post(
        '/',
        Pipeline()
            .addMiddleware(_authMiddleware.requireAdmin)
            .addHandler(_handleCreateManager));

    router.put(
        '/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAdmin).addHandler(
            (request) => _handleUpdateManager(request, request.params['id']!)));

    router.delete(
        '/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAdmin).addHandler(
            (request) => _handleDeleteManager(request, request.params['id']!)));

    return router;
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
      final id = await _managerService.createLinkManager(name, surname, link);

      // Retrieve the created link manager for the response
      final createdManager = await _managerService.getLinkManagerById(id);

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

  Future<Response> _handleDeleteManager(Request request, String id) async {
    final managerId = int.tryParse(id);

    if (managerId == null) {
      return ApiResponse.badRequest('Invalid link manager ID');
    }

    try {
      // First check if the link manager exists and get its details for the response
      final manager = await _managerService.getLinkManagerById(managerId);

      if (manager == null) {
        return ApiResponse.notFound('Link manager not found');
      }

      // Delete the link manager
      final success = await _managerService.deleteLinkManager(managerId);

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

  Future<Response> _handleGetAllManagers(Request request) async {
    try {
      final managers = await _managerService.getAllLinkManagers();
      return ApiResponse.ok({'managers': managers});
    } catch (e, stackTrace) {
      _logger.error('Error retrieving all link managers', e, stackTrace);
      return ApiResponse.serverError('Failed to retrieve link managers',
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
      final manager = await _managerService.getLinkManagerById(managerId);

      if (manager == null) {
        return ApiResponse.notFound('Link manager not found');
      }

      // Get links for this manager
      final links = await _managerService.getLinksByManagerId(managerId);

      return ApiResponse.ok(
          {'manager': manager, 'links': links, 'count': links.length});
    } catch (e, stackTrace) {
      _logger.error(
          'Error retrieving links by manager', e, stackTrace, {'id': id});
      return ApiResponse.serverError('Failed to retrieve links for manager',
          details: e.toString());
    }
  }

  Future<Response> _handleGetManagerById(Request request, String id) async {
    final managerId = int.tryParse(id);

    if (managerId == null) {
      return ApiResponse.badRequest('Invalid link manager ID');
    }

    try {
      final manager = await _managerService.getLinkManagerById(managerId);

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
          await _managerService.getLinkManagerById(managerId);

      if (existingManager == null) {
        return ApiResponse.notFound('Link manager not found');
      }

      // Update the link manager
      final success = await _managerService.updateLinkManager(managerId,
          name: name, surname: surname, link: link);

      if (!success) {
        return ApiResponse.serverError('Failed to update link manager');
      }

      // Retrieve the updated link manager for the response
      final updatedManager = _managerService.getLinkManagerById(managerId);

      _logger.info('Link manager updated', {'id': managerId});
      return ApiResponse.ok({'success': true, 'manager': updatedManager});
    } catch (e, stackTrace) {
      _logger.error('Error updating link manager', e, stackTrace, {'id': id});
      return ApiResponse.serverError('Failed to update link manager',
          details: e.toString());
    }
  }
}
