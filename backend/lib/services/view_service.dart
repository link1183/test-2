import 'package:backend/db/database.dart';
import 'package:backend/utils/logger.dart';

/// Service class for managing views (user groups with access to links)
class ViewService {
  final AppDatabase db;
  final _logger = LoggerFactory.getLogger('ViewService');

  ViewService(this.db);

  /// Create a new view with the given name
  Future<int> createView(String name) async {
    try {
      return await db.createView(name: name);
    } catch (e, stackTrace) {
      _logger.error('Error creating view', e, stackTrace, {'name': name});
      throw Exception('Failed to create view: ${e.toString()}');
    }
  }

  /// Delete a view if it's not used by any links
  Future<bool> deleteView(int id) async {
    try {
      return await db.deleteView(id);
    } catch (e, stackTrace) {
      _logger.error('Error deleting view', e, stackTrace, {'id': id});
      throw Exception('Failed to delete view: ${e.toString()}');
    }
  }

  /// Get all views from the database
  List<Map<String, dynamic>> getAllViews() {
    try {
      return db.getAllViews();
    } catch (e, stackTrace) {
      _logger.error('Error retrieving all views', e, stackTrace);
      throw Exception('Failed to retrieve views');
    }
  }

  /// Get all links associated with a specific view
  List<Map<String, dynamic>> getLinksByViewId(int viewId) {
    try {
      return db.getLinksByViewId(viewId);
    } catch (e, stackTrace) {
      _logger.error('Error retrieving links by view ID', e, stackTrace,
          {'viewId': viewId});
      throw Exception('Failed to retrieve links for view');
    }
  }

  /// Get a specific view by its ID
  Map<String, dynamic>? getViewById(int id) {
    try {
      return db.getViewById(id);
    } catch (e, stackTrace) {
      _logger.error('Error retrieving view by ID', e, stackTrace, {'id': id});
      throw Exception('Failed to retrieve view');
    }
  }

  /// Update an existing view with a new name
  Future<bool> updateView(int id, String name) async {
    try {
      return await db.updateView(id: id, name: name);
    } catch (e, stackTrace) {
      _logger.error(
          'Error updating view', e, stackTrace, {'id': id, 'name': name});
      throw Exception('Failed to update view: ${e.toString()}');
    }
  }
}
