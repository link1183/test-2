import 'package:backend/db/database.dart';
import 'package:backend/utils/logger.dart';

/// Service class for managing link managers (people associated with links)
class LinkManagerService {
  final AppDatabase db;
  final _logger = LoggerFactory.getLogger('LinkManagerService');

  LinkManagerService(this.db);

  /// Create a new link manager with the given details
  Future<int> createLinkManager(
      String name, String surname, String? link) async {
    try {
      // Validate inputs
      if (name.trim().isEmpty) {
        throw Exception('Link manager name cannot be empty');
      }

      if (surname.trim().isEmpty) {
        throw Exception('Link manager surname cannot be empty');
      }

      return await db.createLinkManager(
          name: name, surname: surname, link: link);
    } catch (e, stackTrace) {
      _logger.error('Error creating link manager', e, stackTrace,
          {'name': name, 'surname': surname});
      throw Exception('Failed to create link manager: ${e.toString()}');
    }
  }

  /// Delete a link manager if not associated with any links
  Future<bool> deleteLinkManager(int id) async {
    try {
      return await db.deleteLinkManager(id);
    } catch (e, stackTrace) {
      _logger.error('Error deleting link manager', e, stackTrace, {'id': id});
      throw Exception('Failed to delete link manager: ${e.toString()}');
    }
  }

  /// Get all link managers from the database
  List<Map<String, dynamic>> getAllLinkManagers() {
    try {
      return db.getAllLinkManagers();
    } catch (e, stackTrace) {
      _logger.error('Error retrieving all link managers', e, stackTrace);
      throw Exception('Failed to retrieve link managers');
    }
  }

  /// Get a specific link manager by ID
  Map<String, dynamic>? getLinkManagerById(int id) {
    try {
      return db.getLinkManagerById(id);
    } catch (e, stackTrace) {
      _logger.error(
          'Error retrieving link manager by ID', e, stackTrace, {'id': id});
      throw Exception('Failed to retrieve link manager');
    }
  }

  /// Get all links associated with a specific link manager
  List<Map<String, dynamic>> getLinksByManagerId(int managerId) {
    try {
      return db.getLinksByManagerId(managerId);
    } catch (e, stackTrace) {
      _logger.error('Error retrieving links by manager ID', e, stackTrace,
          {'managerId': managerId});
      throw Exception('Failed to retrieve links for manager');
    }
  }

  /// Update an existing link manager with new details
  Future<bool> updateLinkManager(int id,
      {String? name, String? surname, String? link}) async {
    try {
      // Validate inputs if provided
      if (name != null && name.trim().isEmpty) {
        throw Exception('Link manager name cannot be empty');
      }

      if (surname != null && surname.trim().isEmpty) {
        throw Exception('Link manager surname cannot be empty');
      }

      return await db.updateLinkManager(
          id: id, name: name, surname: surname, link: link);
    } catch (e, stackTrace) {
      _logger.error('Error updating link manager', e, stackTrace, {'id': id});
      throw Exception('Failed to update link manager: ${e.toString()}');
    }
  }
}
