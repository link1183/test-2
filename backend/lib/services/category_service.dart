import 'package:backend/db/database.dart';

class CategoryService {
  final AppDatabase db;

  CategoryService(this.db);

  Future<List<Map<String, dynamic>>> getCategoriesForUser(
      List<String> userGroups) async {
    if (userGroups.isEmpty) {
      return [];
    }

    try {
      return db.getCategoriesForUser(userGroups);
    } catch (e) {
      print('Error in CategoryService.getCategoriesForUser: $e');
      throw Exception('Failed to retrieve categories');
    }
  }
}
