import 'package:backend/db/database_exceptions.dart';
import 'package:backend/utils/logger.dart';
import 'package:sqlite3/sqlite3.dart';

class QueryBuilder {
  final Database _db;
  final _logger = LoggerFactory.getLogger('QueryBuilder');

  QueryBuilder(this._db);

  Future<int> delete(String table,
      {String? where, List<Object?>? whereArgs}) async {
    try {
      String sql = 'DELETE FROM $table';

      if (where != null) {
        sql += ' WHERE $where';
      }

      return execute(sql, whereArgs ?? []);
    } catch (e, stackTrace) {
      _logger.error('Failed to delete from $table', e, stackTrace);
      throw DatabaseException('Failed to delete from $table', e, stackTrace);
    }
  }

  Future<int> execute(String sql, [List<Object?> parameters = const []]) async {
    try {
      final stmt = _db.prepareMultiple(sql);

      try {
        for (var stmt in stmt) {
          stmt.execute(parameters);
        }

        final changes = _db.updatedRows;
        return changes;
      } catch (e, stackTrace) {
        _logger.error('Error in a statement', e, stackTrace);
        return 0;
      } finally {
        for (var stmt in stmt) {
          stmt.dispose();
        }
      }
    } catch (e, stackTrace) {
      _logger.error('Error in a statement', e, stackTrace);
      throw DatabaseException('Failed to execute statement', e, stackTrace);
    }
  }

  Future<int> insert(String table, Map<String, Object?> values) async {
    try {
      final columns = values.keys.join(', ');
      final placeholders = List.filled(values.length, '?').join(', ');

      final sql = 'INSERT INTO $table ($columns) VALUES ($placeholders)';

      await execute(sql, values.values.toList());

      return _db.lastInsertRowId;
    } catch (e, stackTrace) {
      _logger.error('Failed to insert into $table', e, stackTrace);

      if (e.toString().contains('UNIQUE constraint failed')) {
        throw ConstraintException(
            'Unique constraint violation for table $table', e);
      }

      throw DatabaseException('Failed to insert into $table', e, stackTrace);
    }
  }

  Future<List<Map<String, dynamic>>> query(String sql,
      [List<Object?> parameters = const []]) async {
    try {
      final result = _db.select(sql, parameters);

      // Convert to a list of maps
      return result.map((row) => Map<String, dynamic>.from(row)).toList();
    } catch (e, stackTrace) {
      _logger.error('Error executing query: $sql', e, stackTrace);
      throw DatabaseException('Failed to execute query', e, stackTrace);
    }
  }

  Future<int> update(String table, Map<String, Object?> values,
      {String? where, List<Object?>? whereArgs}) async {
    try {
      final setClause = values.keys.map((key) => '$key = ?').join(', ');

      String sql = 'UPDATE $table SET $setClause';

      if (where != null) {
        sql += ' WHERE $where';
      }

      final params = [...values.values, ...?whereArgs];

      return execute(sql, params);
    } catch (e, stackTrace) {
      _logger.error('Failed to update $table', e, stackTrace);
      throw DatabaseException('Failed to update $table', e, stackTrace);
    }
  }
}
