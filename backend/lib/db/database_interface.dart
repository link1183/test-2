import 'package:backend/db/database_config.dart';

/// Interface for database operations
///
/// This provides a common abstraction for different database implementations.
abstract class DatabaseInterface {
  /// The database configuration
  DatabaseConfig get config;

  /// Creates a backup of the database
  ///
  /// @param path The path where the backup should be stored
  /// @returns true if the backup was successful, false otherwise
  Future<bool> backup(String path);

  /// Begins a transaction
  Future<void> beginTransaction();

  /// Closes the database connection
  Future<void> close();

  /// Commits the current transaction
  Future<void> commitTransaction();

  /// Deletes rows from a table
  ///
  /// @param table The table name
  /// @param where Optional WHERE clause
  /// @param whereArgs Optional WHERE arguments
  /// @returns The number of affected rows
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs});

  /// Executes a raw SQL statement that doesn't return data
  ///
  /// @param sql The SQL statement to execute
  /// @param parameters Optional statement parameters
  /// @returns The number of affected rows
  Future<int> execute(String sql, [List<Object?> parameters = const []]);

  /// Gets statistics about the database
  ///
  /// @returns A map containing database statistics
  Future<Map<String, dynamic>> getStats();

  /// Initializes the database
  ///
  /// Creates tables, indexes, and runs migrations as needed.
  Future<void> initialize();

  /// Inserts a row into a table
  ///
  /// @param table The table name
  /// @param values The values to insert
  /// @returns The ID of the inserted row
  Future<int> insert(String table, Map<String, Object?> values);

  /// Checks if the database connection is healthy
  ///
  /// @returns true if the database is connected and operational
  Future<bool> isHealthy();

  /// Executes a raw SQL query that returns data
  ///
  /// @param sql The SQL query to execute
  /// @param parameters Optional query parameters
  /// @returns A list of rows as maps
  Future<List<Map<String, dynamic>>> query(String sql,
      [List<Object?> parameters = const []]);

  /// Rolls back the current transaction
  Future<void> rollbackTransaction();

  /// Updates rows in a table
  ///
  /// @param table The table name
  /// @param values The values to update
  /// @param where Optional WHERE clause
  /// @param whereArgs Optional WHERE arguments
  /// @returns The number of affected rows
  Future<int> update(String table, Map<String, Object?> values,
      {String? where, List<Object?>? whereArgs});
}
