import 'package:backend/db/database.dart';
import 'package:backend/utils/logger.dart';

class StatusService {
  final AppDatabase db;
  final _logger = LoggerFactory.getLogger('StatusService');

  StatusService(this.db);

  Future<int> createStatus(String name) async {
    try {
      return await db.createStatus(name: name);
    } catch (e, stackTrace) {
      _logger.error('Error creating status', e, stackTrace, {'name': name});
      throw Exception('Failed to create status: ${e.toString()}');
    }
  }

  Future<bool> deleteStatus(int id) async {
    try {
      return await db.deleteStatus(id);
    } catch (e, stackTrace) {
      _logger.error('Error deleting status', e, stackTrace, {'id': id});
      throw Exception('Failed to delete status: ${e.toString()}');
    }
  }

  List<Map<String, dynamic>> getAllStatuses() {
    try {
      return db.getAllStatuses();
    } catch (e, stackTrace) {
      _logger.error('Error retrieving all statuses', e, stackTrace);
      throw Exception('Failed to retrieve statuses');
    }
  }

  Future<Map<String, dynamic>?> getStatusById(int id) async {
    try {
      return db.getStatusById(id);
    } catch (e, stackTrace) {
      _logger.error('Error retrieving status by ID', e, stackTrace, {'id': id});
      throw Exception('Failed to retrieve status');
    }
  }

  Future<bool> updateStatus(int id, String name) async {
    try {
      return await db.updateStatus(id: id, name: name);
    } catch (e, stackTrace) {
      _logger.error(
          'Error updating status', e, stackTrace, {'id': id, 'name': name});
      throw Exception('Failed to update status: ${e.toString()}');
    }
  }
}
