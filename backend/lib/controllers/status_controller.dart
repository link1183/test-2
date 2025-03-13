import 'package:backend/middleware/auth_middleware.dart';
import 'package:backend/services/input_sanitizer.dart';
import 'package:backend/services/status_service.dart';
import 'package:backend/utils/api_response.dart';
import 'package:backend/utils/logger.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Controller that handles all category-related API endpoints.
class StatusController {
  final StatusService _statusService;
  final AuthMiddleware _authMiddleware;
  final Logger _logger = LoggerFactory.getLogger('StatusController');

  StatusController(this._statusService, this._authMiddleware);

  /// Returns the router with all status routes defined.
  Router get router {
    final router = Router();

    router.get(
        '/',
        Pipeline()
            .addMiddleware(_authMiddleware.requireAuth)
            .addHandler(_handleGetAllStatuses));

    router.get(
        '/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAuth).addHandler(
            (request) => _handleGetStatusById(request, request.params['id']!)));

    router.post(
        '/',
        Pipeline()
            .addMiddleware(_authMiddleware.requireAdmin)
            .addHandler(_handleCreateStatus));

    router.put(
        '/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAdmin).addHandler(
            (request) => _handleUpdateStatus(request, request.params['id']!)));

    router.delete(
        '/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAdmin).addHandler(
            (request) => _handleDeleteStatus(request, request.params['id']!)));

    return router;
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
      final id = await _statusService.createStatus(name);

      // Retrieve the created status for the response
      final createdStatus = await _statusService.getStatusById(id);

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

  Future<Response> _handleDeleteStatus(Request request, String id) async {
    final statusId = int.tryParse(id);

    if (statusId == null) {
      return ApiResponse.badRequest('Invalid status ID');
    }

    try {
      // First check if the status exists and get its details for the response
      final status = await _statusService.getStatusById(statusId);

      if (status == null) {
        return ApiResponse.notFound('Status not found');
      }

      // Delete the status
      final success = await _statusService.deleteStatus(statusId);

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

  Future<Response> _handleGetAllStatuses(Request request) async {
    try {
      final statuses = _statusService.getAllStatuses();
      return ApiResponse.ok({'statuses': statuses});
    } catch (e, stackTrace) {
      _logger.error('Error retrieving all statuses', e, stackTrace);
      return ApiResponse.serverError('Failed to retrieve statuses',
          details: e.toString());
    }
  }

  Future<Response> _handleGetStatusById(Request request, String id) async {
    final statusId = int.tryParse(id);

    if (statusId == null) {
      return ApiResponse.badRequest('Invalid status ID');
    }

    try {
      final status = await _statusService.getStatusById(statusId);

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
      final status = await _statusService.getStatusById(statusId);

      if (status == null) {
        return ApiResponse.notFound('Status not found');
      }

      // Update the status
      final success = await _statusService.updateStatus(statusId, name);

      if (!success) {
        return ApiResponse.serverError('Failed to update status');
      }

      // Retrieve the updated status for the response
      final updatedStatus = await _statusService.getStatusById(statusId);

      _logger.info('Status updated', {'id': statusId, 'name': name});
      return ApiResponse.ok({'success': true, 'status': updatedStatus});
    } catch (e, stackTrace) {
      _logger.error('Error updating status', e, stackTrace, {'id': id});
      return ApiResponse.serverError('Failed to update status',
          details: e.toString());
    }
  }
}
