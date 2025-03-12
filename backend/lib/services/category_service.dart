import 'package:backend/db/database.dart';
import 'package:backend/utils/logger.dart';

class CategoryService {
  final AppDatabase db;
  final _logger = LoggerFactory.getLogger('CategoryService');

  CategoryService(this.db);

  Future<int> createCategory(String name) async {
    try {
      return await db.createCategory(name: name);
    } catch (e) {
      _logger.error('Failed to create category', e);
      throw Exception('Failed to create category: ${e.toString()}');
    }
  }

  Future<bool> deleteCategory(int id) async {
    try {
      return await db.deleteCategory(id);
    } catch (e) {
      _logger.error('Failed to delete category', e);
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
      _logger.error('Failed to get categories', e);
      throw Exception('Failed to retrieve categories');
    }
  }

  Future<Map<String, dynamic>?> getCategoryById(int id) async {
    try {
      return db.getCategoryById(id);
    } catch (e) {
      _logger.error('Failed to get category', e);
      throw Exception('Failed to retrieve category');
    }
  }

  Future<bool> updateCategory(int id, String name) async {
    try {
      return await db.updateCategory(id: id, name: name);
    } catch (e) {
      _logger.error('Failed to update category', e);
      throw Exception('Failed to update category: ${e.toString()}');
    }
  }
}
