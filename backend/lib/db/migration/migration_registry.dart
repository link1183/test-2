import 'package:backend/db/migration/migration.dart';
import 'package:backend/db/migration/migrations/001_initial_schema.dart';
import 'package:backend/db/migration/migrations/002_initial_data.dart';

/// Registry of all database migrations
class MigrationRegistry {
  /// Returns the migration manager with all registered migrations
  static MigrationManager getManager() {
    return MigrationManager(getMigrations());
  }

  /// Returns all registered migrations
  static List<Migration> getMigrations() {
    return [
      InitialSchemaMigration(),
      //InitialData(),
    ];
  }
}
