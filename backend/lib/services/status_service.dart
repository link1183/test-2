import 'package:backend/db/database_connection_pool.dart';
import 'package:backend/db/database_exceptions.dart';
import 'package:backend/utils/logger.dart';

/// Data model for Status
class Status {
  final int? id;
  final String name;

  Status({this.id, required this.name});

  /// Creates a status from a database row
  factory Status.fromMap(Map<String, dynamic> map) {
    return Status(
      id: map['id'] as int,
      name: map['name'] as String,
    );
  }

  /// Creates a copy of this status with optional overrides
  Status copyWith({int? id, String? name}) {
    return Status(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  /// Converts this status to a database row
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
    };
  }
}

/// Service for managing statuses
class StatusService {
  final DatabaseConnectionPool _connectionPool;
  final Logger _logger = LoggerFactory.getLogger('StatusService');

  StatusService(this._connectionPool);

  /// Creates a new status
  Future<int> createStatus(String name) async {
    try {
      // Validate inputs
      if (name.trim().isEmpty) {
        throw ArgumentError('Status name cannot be empty');
      }

      final connection = await _connectionPool.getConnection();

      try {
        // Check if a status with this name already exists
        final existingStatuses = await connection.database.query(
          'SELECT id FROM status WHERE name = ?',
          [name],
        );

        if (existingStatuses.isNotEmpty) {
          throw ConstraintException('A status with this name already exists');
        }

        // Insert the status
        final id = await connection.database.insert('status', {'name': name});

        _logger.info('Created new status', {'id': id, 'name': name});
        return id;
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      if (e is ConstraintException || e is ArgumentError) {
        _logger.warning(e.toString());
        rethrow;
      }

      _logger.error('Failed to create status', e, stackTrace);
      throw DatabaseException('Failed to create status', e, stackTrace);
    }
  }

  /// Deletes a status by ID
  Future<bool> deleteStatus(int id) async {
    try {
      final connection = await _connectionPool.getConnection();

      try {
        // Check if the status exists
        final statusExists = await connection.database.query(
          'SELECT 1 FROM status WHERE id = ?',
          [id],
        );

        if (statusExists.isEmpty) {
          _logger.warning('Status not found for deletion', {'id': id});
          return false;
        }

        // Check if there are any links using this status
        final linkedLinks = await connection.database.query(
          'SELECT COUNT(*) as count FROM link WHERE status_id = ?',
          [id],
        );

        final linkCount = linkedLinks.first['count'] as int;
        if (linkCount > 0) {
          throw ConstraintException(
            'Cannot delete status: it is used by $linkCount links',
          );
        }

        // Start a transaction
        await connection.database.beginTransaction();

        try {
          // Delete the status
          await connection.database.delete(
            'status',
            where: 'id = ?',
            whereArgs: [id],
          );

          await connection.database.commitTransaction();

          _logger.info('Deleted status', {'id': id});
          return true;
        } catch (e) {
          await connection.database.rollbackTransaction();
          rethrow;
        }
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      if (e is ConstraintException) {
        _logger.warning(e.toString());
        rethrow;
      }

      _logger.error('Failed to delete status', e, stackTrace);
      throw DatabaseException(
          'Failed to delete status: ${e.toString()}', e, stackTrace);
    }
  }

  /// Gets all statuses
  Future<List<Status>> getAllStatuses() async {
    try {
      final connection = await _connectionPool.getConnection();

      try {
        final results = await connection.database.query(
          'SELECT id, name FROM status ORDER BY name',
        );

        return results.map((row) => Status.fromMap(row)).toList();
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to get all statuses', e, stackTrace);
      throw DatabaseException('Failed to retrieve statuses', e, stackTrace);
    }
  }

  /// Gets a status by ID
  Future<Status?> getStatusById(int id) async {
    try {
      final connection = await _connectionPool.getConnection();

      try {
        final results = await connection.database.query(
          'SELECT id, name FROM status WHERE id = ?',
          [id],
        );

        if (results.isEmpty) {
          return null;
        }

        return Status.fromMap(results.first);
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to get status by ID', e, stackTrace);
      throw DatabaseException('Failed to retrieve status', e, stackTrace);
    }
  }

  /// Updates a status
  Future<bool> updateStatus(int id, String name) async {
    try {
      // Validate inputs
      if (name.trim().isEmpty) {
        throw ArgumentError('Status name cannot be empty');
      }

      final connection = await _connectionPool.getConnection();

      try {
        // Check if the status exists
        final statusExists = await connection.database.query(
          'SELECT 1 FROM status WHERE id = ?',
          [id],
        );

        if (statusExists.isEmpty) {
          _logger.warning('Status not found for update', {'id': id});
          return false;
        }

        // Check if another status with this name already exists
        final existingStatus = await connection.database.query(
          'SELECT id FROM status WHERE name = ? AND id != ?',
          [name, id],
        );

        if (existingStatus.isNotEmpty) {
          throw ConstraintException(
              'Another status with this name already exists');
        }

        // Update the status
        await connection.database.update(
          'status',
          {'name': name},
          where: 'id = ?',
          whereArgs: [id],
        );

        _logger.info('Updated status', {'id': id, 'name': name});
        return true;
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      if (e is ConstraintException || e is ArgumentError) {
        _logger.warning(e.toString());
        rethrow;
      }

      _logger.error('Failed to update status', e, stackTrace);
      throw DatabaseException(
          'Failed to update status: ${e.toString()}', e, stackTrace);
    }
  }
}

