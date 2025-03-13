import 'dart:io';

import 'package:backend/db/database_config.dart' as backend;
import 'package:backend/db/database_exceptions.dart';
import 'package:backend/db/database_interface.dart';
import 'package:backend/utils/logger.dart';
import 'package:sqlite3/sqlite3.dart';

/// SQLite implementation of the DatabaseInterface
class SqliteDatabase implements DatabaseInterface {
  @override
  final backend.DatabaseConfig config;

  late final Database _db;
  final Logger _logger = LoggerFactory.getLogger('SqliteDatabase');
  bool _initialized = false;
  bool _inTransaction = false;

  SqliteDatabase(this.config);

  @override
  Future<bool> backup(String path) async {
    _logger.info('Starting database backup to $path...');

    try {
      final sourceFile = File(config.dbPath);

      // Make sure the database is in a consistent state
      if (config.enableWal) {
        _db.execute('PRAGMA wal_checkpoint;');
      }

      await sourceFile.copy(path);

      final sourceSize = await sourceFile.length();
      final backupSize = await File(path).length();

      _logger.info('Database backup completed successfully',
          {'sourceSize': sourceSize, 'backupSize': backupSize});

      return true;
    } catch (e, stackTrace) {
      _logger.error('Database backup failed', e, stackTrace);
      return false;
    }
  }

  @override
  Future<void> beginTransaction() async {
    if (_inTransaction) {
      throw DatabaseException('Transaction already in progress');
    }

    try {
      _db.execute('BEGIN TRANSACTION;');
      _inTransaction = true;
    } catch (e, stackTrace) {
      _logger.error('Failed to begin transaction', e, stackTrace);
      throw DatabaseException('Failed to begin transaction', e, stackTrace);
    }
  }

  @override
  Future<void> close() async {
    if (_initialized) {
      try {
        _db.dispose();
        _initialized = false;
        _logger.info('Database connection closed');
      } catch (e, stackTrace) {
        _logger.error('Error closing database connection', e, stackTrace);
        throw DatabaseException('Failed to close database', e, stackTrace);
      }
    }
  }

  @override
  Future<void> commitTransaction() async {
    if (!_inTransaction) {
      throw DatabaseException('No transaction in progress');
    }

    try {
      _db.execute('COMMIT;');
      _inTransaction = false;
    } catch (e, stackTrace) {
      _logger.error('Failed to commit transaction', e, stackTrace);
      throw DatabaseException('Failed to commit transaction', e, stackTrace);
    }
  }

  @override
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

  @override
  Future<int> execute(String sql, [List<Object?> parameters = const []]) async {
    try {
      final stmt = _db.prepareMultiple(sql);
      _logger.debug('Executing statement');

      try {
        for (var stmt in stmt) {
          stmt.execute(parameters);
        }
        final changes = _db.updatedRows;
        _logger.debug('Statement executed: $changes');
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
      _logger.error('Error executing SQL: $sql', e, stackTrace);
      throw DatabaseException('Failed to execute SQL', e, stackTrace);
    }
  }

  @override
  Future<Map<String, dynamic>> getStats() async {
    try {
      return {
        'size_kb': File(config.dbPath).lengthSync() ~/ 1024,
        'page_count': _db.select('PRAGMA page_count;').first['page_count'],
        'page_size': _db.select('PRAGMA page_size;').first['page_size'],
        'schema_version': _db
                .select(
                    "SELECT value FROM db_metadata WHERE key = 'schema_version';")
                .firstOrNull?['value'] ??
            '0',
        'tables': _db
            .select(
                "SELECT name, (SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND tbl_name=m.name) as index_count FROM sqlite_master m WHERE type='table' AND name NOT LIKE 'sqlite_%';")
            .map((row) => {
                  'name': row['name'],
                  'index_count': row['index_count'],
                })
            .toList(),
      };
    } catch (e, stackTrace) {
      _logger.error('Failed to get database stats', e, stackTrace);
      throw DatabaseException('Failed to get database stats', e, stackTrace);
    }
  }

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _logger.info('Initializing SQLite database...', {'path': config.dbPath});

    try {
      // Ensure the directory exists
      if (!config.inMemory) {
        final dbDir = Directory(
            config.dbPath.substring(0, config.dbPath.lastIndexOf('/')));
        if (!dbDir.existsSync()) {
          dbDir.createSync(recursive: true);
        }

        // Create backup directory
        final backupDir = Directory(config.backupDirectory);
        if (!backupDir.existsSync()) {
          backupDir.createSync(recursive: true);
        }
      }

      // Open the database connection
      _db = sqlite3.open(config.dbPath);

      // Configure SQLite
      if (config.enableForeignKeys) {
        _db.execute('PRAGMA foreign_keys = ON;');
      }

      if (config.enableWal && !config.inMemory) {
        _db.execute('PRAGMA journal_mode = WAL;');
      }

      // Create metadata table if it doesn't exist
      _db.execute('''
        CREATE TABLE IF NOT EXISTS db_metadata (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        );
      ''');

      _initialized = true;
      _logger.info('SQLite database initialized successfully');
    } catch (e, stackTrace) {
      _logger.critical('Failed to initialize database', e, stackTrace);
      throw DatabaseInitException(
          'Failed to initialize SQLite database', e, stackTrace);
    }
  }

  @override
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

  @override
  Future<bool> isHealthy() async {
    try {
      _db.execute('SELECT 1');
      return true;
    } catch (e) {
      _logger.error('Database health check failed', e);
      return false;
    }
  }

  @override
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

  @override
  Future<void> rollbackTransaction() async {
    if (!_inTransaction) {
      throw DatabaseException('No transaction in progress');
    }

    try {
      _db.execute('ROLLBACK;');
      _inTransaction = false;
    } catch (e, stackTrace) {
      _logger.error('Failed to rollback transaction', e, stackTrace);
      throw DatabaseException('Failed to rollback transaction', e, stackTrace);
    }
  }

  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    await beginTransaction();

    try {
      final result = await action();
      await commitTransaction();
      return result;
    } catch (e) {
      await rollbackTransaction();
      rethrow;
    }
  }

  @override
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
