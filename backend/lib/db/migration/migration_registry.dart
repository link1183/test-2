import 'package:backend/db/migration/migration.dart';
import 'package:backend/db/migration/migrations/001_initial_schema.dart';

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
      // Add new migrations here in version order
    ];
  }
}
