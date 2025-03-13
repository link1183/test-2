import 'package:backend/middleware/auth_middleware.dart';
import 'package:backend/services/category_service.dart';
import 'package:backend/services/input_sanitizer.dart';
import 'package:backend/utils/api_response.dart';
import 'package:backend/utils/logger.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Controller that handles all category-related API endpoints.
class CategoryController {
  final CategoryService _categoryService;
  final AuthMiddleware _authMiddleware;
  final Logger _logger = LoggerFactory.getLogger('CategoryController');

  CategoryController(this._categoryService, this._authMiddleware);

  /// Returns the router with all category routes defined.
  Router get router {
    final router = Router();

    // Get all categories - requires authentication
    router.get(
        '/',
        Pipeline()
            .addMiddleware(_authMiddleware.requireAuth)
            .addHandler(_handleGetAllCategories));

    // Get category by ID - requires authentication
    router.get(
        '/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAuth).addHandler(
            (request) =>
                _handleGetCategoryById(request, request.params['id']!)));

    // Create category - requires admin privileges
    router.post(
        '/',
        Pipeline()
            .addMiddleware(_authMiddleware.requireAdmin)
            .addHandler(_handleCreateCategory));

    // Update category - requires admin privileges
    router.put(
        '/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAdmin).addHandler(
            (request) =>
                _handleUpdateCategory(request, request.params['id']!)));

    // Delete category - requires admin privileges
    router.delete(
        '/<id>',
        Pipeline().addMiddleware(_authMiddleware.requireAdmin).addHandler(
            (request) =>
                _handleDeleteCategory(request, request.params['id']!)));

    return router;
  }

  /// Handler for POST /api/categories
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
      final id = await _categoryService.createCategory(name);

      // Retrieve the created category for the response
      final createdCategory = await _categoryService.getCategoryById(id);

      if (createdCategory == null) {
        return ApiResponse.serverError(
            'Category was created but could not be retrieved');
      }

      _logger.info('Category created', {'id': id, 'name': name});
      return ApiResponse.ok({'success': true, 'category': createdCategory});
    } catch (e, stackTrace) {
      _logger.error('Error creating category', e, stackTrace);
      return ApiResponse.serverError('Failed to create category',
          details: e.toString());
    }
  }

  /// Handler for DELETE /api/categories/:id
  Future<Response> _handleDeleteCategory(Request request, String id) async {
    final categoryId = int.tryParse(id);

    if (categoryId == null) {
      return ApiResponse.badRequest('Invalid category ID');
    }

    try {
      // First check if the category exists and get its details for the response
      final category = await _categoryService.getCategoryById(categoryId);

      if (category == null) {
        return ApiResponse.notFound('Category not found');
      }

      // Delete the category
      final success = await _categoryService.deleteCategory(categoryId);

      if (!success) {
        return ApiResponse.serverError('Failed to delete category');
      }

      _logger.info('Category deleted', {'id': categoryId});
      return ApiResponse.ok({'success': true, 'deletedCategory': category});
    } catch (e, stackTrace) {
      _logger.error('Error deleting category', e, stackTrace, {'id': id});
      return ApiResponse.serverError('Failed to delete category',
          details: e.toString());
    }
  }

  /// Handler for GET /api/categories
  Future<Response> _handleGetAllCategories(Request request) async {
    try {
      final categories = await _categoryService.getAllCategories();
      return ApiResponse.ok({'categories': categories});
    } catch (e, stackTrace) {
      _logger.error('Failed to get all categories', e, stackTrace);
      return ApiResponse.serverError('Failed to retrieve categories',
          details: e.toString());
    }
  }

  /// Handler for GET /api/categories/:id
  Future<Response> _handleGetCategoryById(Request request, String id) async {
    final categoryId = int.tryParse(id);

    if (categoryId == null) {
      return ApiResponse.badRequest('Invalid category ID');
    }

    try {
      final category = await _categoryService.getCategoryById(categoryId);

      if (category == null) {
        return ApiResponse.notFound('Category not found');
      }

      return ApiResponse.ok({'category': category});
    } catch (e, stackTrace) {
      _logger.error('Error retrieving category', e, stackTrace, {'id': id});
      return ApiResponse.serverError('Failed to retrieve category',
          details: e.toString());
    }
  }

  /// Handler for PUT /api/categories/:id
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

      // Update the category
      final success = await _categoryService.updateCategory(categoryId, name);

      if (!success) {
        return ApiResponse.notFound('Category not found');
      }

      // Retrieve the updated category for the response
      final updatedCategory =
          await _categoryService.getCategoryById(categoryId);

      _logger.info('Category updated', {'id': categoryId, 'name': name});
      return ApiResponse.ok({'success': true, 'category': updatedCategory});
    } catch (e, stackTrace) {
      _logger.error('Error updating category', e, stackTrace, {'id': id});
      return ApiResponse.serverError('Failed to update category',
          details: e.toString());
    }
  }
}
