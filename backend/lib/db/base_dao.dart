import 'package:backend/db/database_connection_pool.dart';
import 'package:backend/db/database_exceptions.dart';
import 'package:backend/utils/logger.dart';

/// Base Data Access Object (DAO) class
///
/// Provides common database operations for a specific table/entity type.
/// Implement this class for each entity in your application.
abstract class BaseDao<T> {
  final DatabaseConnectionPool connectionPool;
  final String tableName;
  final Logger _logger;

  BaseDao(this.connectionPool, this.tableName)
      : _logger = LoggerFactory.getLogger('DAO-$tableName');

  /// Gets the primary key column name
  String get primaryKeyColumn => 'id';

  /// Gets a human-readable entity name for logging
  String get _entityName => tableName.replaceAll('_', ' ');

  /// Creates an entity in the database
  Future<int> create(T entity) async {
    final connection = await connectionPool.getConnection();

    try {
      final map = toMap(entity);
      final id = await connection.database.insert(tableName, map);
      _logger.debug('Created $_entityName record', {'id': id});
      return id;
    } catch (e, stackTrace) {
      _logger.error('Failed to create $_entityName', e, stackTrace);

      if (e is ConstraintException) {
        rethrow;
      }

      throw DatabaseException('Failed to create $_entityName', e, stackTrace);
    } finally {
      await connection.release();
    }
  }

  /// Deletes an entity from the database
  Future<bool> delete(dynamic id) async {
    final connection = await connectionPool.getConnection();

    try {
      final result = await connection.database.delete(
        tableName,
        where: '$primaryKeyColumn = ?',
        whereArgs: [id],
      );

      if (result > 0) {
        _logger.debug('Deleted $_entityName record', {'id': id});
        return true;
      } else {
        _logger.debug('$_entityName record not found for deletion', {'id': id});
        return false;
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to delete $_entityName', e, stackTrace);
      throw DatabaseException('Failed to delete $_entityName', e, stackTrace);
    } finally {
      await connection.release();
    }
  }

  /// Checks if an entity exists by ID
  Future<bool> exists(dynamic id) async {
    final connection = await connectionPool.getConnection();

    try {
      final result = await connection.database.query(
        'SELECT 1 FROM $tableName WHERE $primaryKeyColumn = ? LIMIT 1',
        [id],
      );

      return result.isNotEmpty;
    } catch (e, stackTrace) {
      _logger.error('Failed to check if $_entityName exists', e, stackTrace);
      throw DatabaseException(
          'Failed to check if $_entityName exists', e, stackTrace);
    } finally {
      await connection.release();
    }
  }

  /// Finds all entities in the database
  Future<List<T>> findAll({
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final connection = await connectionPool.getConnection();

    try {
      String query = 'SELECT * FROM $tableName';

      if (orderBy != null) {
        query += ' ORDER BY $orderBy';
      }

      if (limit != null) {
        query += ' LIMIT $limit';

        if (offset != null) {
          query += ' OFFSET $offset';
        }
      }

      final rows = await connection.database.query(query);
      return rows.map((row) => fromMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Failed to find all ${_entityName}s', e, stackTrace);
      throw DatabaseException(
          'Failed to find all ${_entityName}s', e, stackTrace);
    } finally {
      await connection.release();
    }
  }

  /// Finds an entity by ID
  Future<T?> findById(dynamic id) async {
    final connection = await connectionPool.getConnection();

    try {
      final rows = await connection.database.query(
        'SELECT * FROM $tableName WHERE $primaryKeyColumn = ?',
        [id],
      );

      if (rows.isEmpty) {
        return null;
      }

      return fromMap(rows.first);
    } catch (e, stackTrace) {
      _logger.error('Failed to find $_entityName by ID', e, stackTrace);
      throw DatabaseException(
          'Failed to find $_entityName by ID', e, stackTrace);
    } finally {
      await connection.release();
    }
  }

  /// Finds entities based on a WHERE clause
  Future<List<T>> findWhere({
    required String where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final connection = await connectionPool.getConnection();

    try {
      String query = 'SELECT * FROM $tableName WHERE $where';

      if (orderBy != null) {
        query += ' ORDER BY $orderBy';
      }

      if (limit != null) {
        query += ' LIMIT $limit';

        if (offset != null) {
          query += ' OFFSET $offset';
        }
      }

      final rows = await connection.database.query(query, whereArgs ?? []);
      return rows.map((row) => fromMap(row)).toList();
    } catch (e, stackTrace) {
      _logger.error(
          'Failed to find ${_entityName}s by condition', e, stackTrace);
      throw DatabaseException(
          'Failed to find ${_entityName}s by condition', e, stackTrace);
    } finally {
      await connection.release();
    }
  }

  /// Converts a database row to an entity object
  T fromMap(Map<String, dynamic> map);

  /// Converts an entity object to a database row
  Map<String, dynamic> toMap(T entity);

  /// Updates an entity in the database
  Future<bool> update(dynamic id, T entity) async {
    final connection = await connectionPool.getConnection();

    try {
      final map = toMap(entity);

      // Remove the ID from the map if it's included
      map.remove(primaryKeyColumn);

      final result = await connection.database.update(
        tableName,
        map,
        where: '$primaryKeyColumn = ?',
        whereArgs: [id],
      );

      if (result > 0) {
        _logger.debug('Updated $_entityName record', {'id': id});
        return true;
      } else {
        _logger.debug('$_entityName record not found for update', {'id': id});
        return false;
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to update $_entityName', e, stackTrace);

      if (e is ConstraintException) {
        rethrow;
      }

      throw DatabaseException('Failed to update $_entityName', e, stackTrace);
    } finally {
      await connection.release();
    }
  }
}
