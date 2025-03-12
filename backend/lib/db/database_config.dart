import 'dart:io';

/// Configuration for database connections
class DatabaseConfig {
  /// Path to the database file
  final String dbPath;

  /// Whether to use an in-memory database (for testing)
  final bool inMemory;

  /// Maximum number of concurrent connections in the pool
  final int maxConnections;

  /// Additional database configuration options
  final Map<String, String> extraOptions;

  /// Directory for database backups
  final String backupDirectory;

  /// Whether to enable WAL mode
  final bool enableWal;

  /// Whether to enable foreign keys
  final bool enableForeignKeys;

  /// Creates a database configuration
  DatabaseConfig({
    required this.dbPath,
    this.inMemory = false,
    this.maxConnections = 1,
    this.extraOptions = const {},
    this.backupDirectory = '/data/backup',
    this.enableWal = true,
    this.enableForeignKeys = true,
  });

  /// Creates a configuration from environment variables
  factory DatabaseConfig.fromEnvironment() {
    // Create backup directory path
    final backupDir = Platform.environment['DB_BACKUP_DIR'] ?? '/data/backup';

    return DatabaseConfig(
      dbPath: Platform.environment['DB_PATH'] ?? '/data/data.db',
      inMemory: Platform.environment['DB_IN_MEMORY'] == 'true',
      maxConnections:
          int.tryParse(Platform.environment['DB_MAX_CONNECTIONS'] ?? '1') ?? 1,
      backupDirectory: backupDir,
      enableWal: Platform.environment['DB_ENABLE_WAL'] != 'false',
      enableForeignKeys:
          Platform.environment['DB_ENABLE_FOREIGN_KEYS'] != 'false',
    );
  }

  /// Creates a configuration for testing with an in-memory database
  factory DatabaseConfig.forTesting() {
    return DatabaseConfig(
      dbPath: ':memory:',
      inMemory: true,
      maxConnections: 1,
      backupDirectory: '/tmp',
      enableWal: false, // WAL mode doesn't work with in-memory databases
    );
  }

  /// Deep copy of this configuration with optional overrides
  DatabaseConfig copyWith({
    String? dbPath,
    bool? inMemory,
    int? maxConnections,
    Map<String, String>? extraOptions,
    String? backupDirectory,
    bool? enableWal,
    bool? enableForeignKeys,
  }) {
    return DatabaseConfig(
      dbPath: dbPath ?? this.dbPath,
      inMemory: inMemory ?? this.inMemory,
      maxConnections: maxConnections ?? this.maxConnections,
      extraOptions: extraOptions ?? Map.from(this.extraOptions),
      backupDirectory: backupDirectory ?? this.backupDirectory,
      enableWal: enableWal ?? this.enableWal,
      enableForeignKeys: enableForeignKeys ?? this.enableForeignKeys,
    );
  }
}

