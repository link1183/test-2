import 'package:backend/db/database_config.dart';
import 'package:backend/db/database_connection_pool.dart';
import 'package:backend/db/database_exceptions.dart';
import 'package:backend/db/database_interface.dart';
import 'package:backend/db/migration/migration_registry.dart';
import 'package:backend/db/sqlite_database.dart';
import 'package:backend/utils/logger.dart';

/// Factory for creating and initializing databases
class DatabaseFactory {
  final Logger _logger = LoggerFactory.getLogger('DatabaseFactory');

  /// Creates and initializes a connection pool using the provided config
  Future<DatabaseConnectionPool> createConnectionPool(
      DatabaseConfig config) async {
    _logger.info('Creating database connection pool', {
      'path': config.dbPath,
      'maxConnections': config.maxConnections,
    });

    // Create a connection pool
    final pool = DatabaseConnectionPool(config);

    // Get a connection to initialize the database
    final connection = await pool.getConnection();

    try {
      // Run migrations if needed
      await _initializeWithMigrations(connection.database);
      return pool;
    } catch (e, stackTrace) {
      // Clean up on error
      await pool.shutdown();
      _logger.critical(
          'Failed to initialize database connection pool', e, stackTrace);
      throw DatabaseInitException(
          'Failed to initialize database', e, stackTrace);
    } finally {
      // Always release the connection back to the pool
      await connection.release();
    }
  }

  /// Creates a standalone database connection (without a pool)
  Future<DatabaseInterface> createDatabase(DatabaseConfig config) async {
    _logger.info('Creating standalone database connection', {
      'path': config.dbPath,
    });

    final db = SqliteDatabase(config);

    try {
      // Initialize the database
      await db.initialize();

      // Run migrations if needed
      await _initializeWithMigrations(db);

      return db;
    } catch (e, stackTrace) {
      // Clean up on error
      await db.close();
      _logger.critical('Failed to initialize database', e, stackTrace);
      throw DatabaseInitException(
          'Failed to initialize database', e, stackTrace);
    }
  }

  /// Initializes the database with all pending migrations
  Future<void> _initializeWithMigrations(DatabaseInterface db) async {
    try {
      // Get the current database version
      final versionResult = await db
          .query("SELECT value FROM db_metadata WHERE key = 'schema_version';");

      final currentVersion = versionResult.isEmpty
          ? 0
          : int.parse(versionResult.first['value'] as String);

      _logger.info('Current database schema version: $currentVersion');

      // Get the migration manager
      final migrationManager = MigrationRegistry.getManager();

      // Check if migrations are needed
      if (currentVersion < migrationManager.latestVersion) {
        _logger.info(
            'Running migrations from v$currentVersion to v${migrationManager.latestVersion}');

        // Run all pending migrations
        await migrationManager.migrateToLatest(db, currentVersion);

        _logger.info('Database migrations completed successfully');
      } else {
        _logger.info(
            'Database is already at the latest version (v$currentVersion)');
      }
    } catch (e, stackTrace) {
      _logger.error(
          'Failed to initialize database with migrations', e, stackTrace);
      throw DatabaseInitException(
          'Failed to initialize database with migrations', e, stackTrace);
    }
  }
}
