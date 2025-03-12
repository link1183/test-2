import 'package:backend/db/database_exceptions.dart';
import 'package:backend/db/database_interface.dart';
import 'package:backend/utils/logger.dart';

/// Base class for database migrations
abstract class Migration {
  /// The migration version number
  final int version;

  /// A description of the migration
  final String description;

  /// Logger for the migration
  final Logger _logger = LoggerFactory.getLogger('Migration');

  Migration(this.version, this.description);

  /// Reverses the migration (downgrade)
  Future<void> down(DatabaseInterface db);

  /// Logs migration information
  void log(String message) {
    _logger.info('Migration v$version: $message');
  }

  /// Logs migration error
  void logError(String message, Object error, [StackTrace? stackTrace]) {
    _logger.error('Migration v$version error: $message', error, stackTrace);
  }

  /// Applies the migration (upgrade)
  Future<void> up(DatabaseInterface db);
}

/// Manager for handling database migrations
class MigrationManager {
  final List<Migration> _migrations;
  final Logger _logger = LoggerFactory.getLogger('MigrationManager');

  MigrationManager(List<Migration> migrations)
      : _migrations = List.from(migrations) {
    // Sort migrations by version
    _migrations.sort((a, b) => a.version.compareTo(b.version));
  }

  /// Gets the latest migration version
  int get latestVersion => _migrations.isEmpty ? 0 : _migrations.last.version;

  /// Gets all registered migrations
  List<Migration> get migrations => List.unmodifiable(_migrations);

  /// Migrates the database down to a specific version
  Future<void> migrateDown(
      DatabaseInterface db, int currentVersion, int targetVersion) async {
    if (targetVersion >= currentVersion) {
      throw MigrationException(currentVersion,
          'Target version ($targetVersion) must be less than current version ($currentVersion)');
    }

    _logger.info(
        'Starting migration downgrade from v$currentVersion to v$targetVersion');

    try {
      await db.beginTransaction();

      // Get migrations to roll back in reverse order
      final migrationsToRollback = _migrations
          .where(
              (m) => m.version <= currentVersion && m.version > targetVersion)
          .toList()
        ..sort((a, b) => b.version.compareTo(a.version)); // Reverse order

      for (final migration in migrationsToRollback) {
        _logger.info(
            'Rolling back migration v${migration.version}: ${migration.description}');

        try {
          await migration.down(db);

          // Update schema version to the previous version
          final previousVersion = migrationsToRollback.indexOf(migration) ==
                  migrationsToRollback.length - 1
              ? targetVersion
              : migrationsToRollback[
                      migrationsToRollback.indexOf(migration) + 1]
                  .version;

          await db.execute(
              "INSERT OR REPLACE INTO db_metadata (key, value) VALUES ('schema_version', ?)",
              [previousVersion.toString()]);

          _logger.info(
              'Rollback of migration v${migration.version} completed successfully');
        } catch (e, stackTrace) {
          final message = 'Failed to roll back migration v${migration.version}';
          _logger.error(message, e, stackTrace);
          await db.rollbackTransaction();
          throw MigrationException(migration.version, message, e, stackTrace);
        }
      }

      await db.commitTransaction();
      _logger.info(
          'Migration downgrade to v$targetVersion completed successfully');
    } catch (e, stackTrace) {
      if (e is! MigrationException) {
        _logger.error('Migration downgrade process failed', e, stackTrace);
        await db.rollbackTransaction();
        throw MigrationException(currentVersion,
            'Migration downgrade process failed', e, stackTrace);
      }
      rethrow;
    }
  }

  /// Migrates the database to the latest version
  Future<void> migrateToLatest(DatabaseInterface db, int currentVersion) async {
    _logger.info('Starting migration from v$currentVersion to v$latestVersion');

    if (currentVersion == latestVersion) {
      _logger
          .info('Database is already at the latest version (v$latestVersion)');
      return;
    }

    if (currentVersion > latestVersion) {
      final message =
          'Current database version ($currentVersion) is higher than the latest migration ($latestVersion)';
      _logger.error(message);
      throw MigrationException(currentVersion, message);
    }

    try {
      await db.beginTransaction();

      for (final migration
          in _migrations.where((m) => m.version > currentVersion)) {
        _logger.info(
            'Running migration v${migration.version}: ${migration.description}');

        try {
          await migration.up(db);

          // Update schema version
          await db.execute(
              "INSERT OR REPLACE INTO db_metadata (key, value) VALUES ('schema_version', ?)",
              [migration.version.toString()]);

          _logger
              .info('Migration v${migration.version} completed successfully');
        } catch (e, stackTrace) {
          final message = 'Failed to apply migration v${migration.version}';
          _logger.error(message, e, stackTrace);
          await db.rollbackTransaction();
          throw MigrationException(migration.version, message, e, stackTrace);
        }
      }

      await db.commitTransaction();
      _logger.info('Migration to v$latestVersion completed successfully');
    } catch (e, stackTrace) {
      if (e is! MigrationException) {
        _logger.error('Migration process failed', e, stackTrace);
        await db.rollbackTransaction();
        throw MigrationException(
            currentVersion, 'Migration process failed', e, stackTrace);
      }
      rethrow;
    }
  }
}
