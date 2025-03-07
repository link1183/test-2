import 'package:backend/db/database.dart';
import 'package:backend/utils/logger.dart';

class CategoryService {
  final AppDatabase db;

  final _logger = LoggerFactory.getLogger('CategoryService');
  CategoryService(this.db);

  Future<int> createCategory(String name) async {
    try {
      return await db.createCategory(name: name);
    } catch (e, stackTrace) {
      _logger.error('Error creating category', e, stackTrace, {'name': name});
      throw Exception('Failed to create category: ${e.toString()}');
    }
  }

  Future<bool> deleteCategory(int id) async {
    try {
      return await db.deleteCategory(id);
    } catch (e, stackTrace) {
      _logger.error('Error deleting category', e, stackTrace, {'id': id});
      throw Exception('Failed to delete category: ${e.toString()}');
    }
  }

  Future<List<Map<String, dynamic>>> getCategoriesForUser(
      List<String> userGroups) async {
    if (userGroups.isEmpty) {
      return [];
    }

    try {
      return db.getCategoriesForUser(userGroups);
    } catch (e) {
      _logger.error('Error in CategoryService.getCategoriesForUser', e);
      throw Exception('Failed to retrieve categories');
    }
  }

  Future<Map<String, dynamic>?> getCategoryById(int id) async {
    try {
      return db.getCategoryById(id);
    } catch (e, stackTrace) {
      _logger
          .error('Error retrieving category by ID', e, stackTrace, {'id': id});
      throw Exception('Failed to retrieve category');
    }
  }

  Future<bool> updateCategory(int id, String name) async {
    try {
      return await db.updateCategory(id: id, name: name);
    } catch (e, stackTrace) {
      _logger.error(
          'Error updating category', e, stackTrace, {'id': id, 'name': name});
      throw Exception('Failed to update category: ${e.toString()}');
    }
  }
}
