/// Exception thrown when an operation is attempted on a closed connection
class ConnectionClosedException extends DatabaseException {
  ConnectionClosedException(
      [super.message = 'Connection is closed', super.cause]);
}

/// Exception thrown when a database connection cannot be acquired
class ConnectionException extends DatabaseException {
  ConnectionException(super.message, [super.cause, super.stackTrace]);

  @override
  String toString() =>
      'ConnectionException: $message${cause != null ? ' (Cause: $cause)' : ''}';
}

/// Exception thrown when database constraints are violated
class ConstraintException extends DatabaseException {
  ConstraintException(super.message, [super.cause]);
}

/// Base exception class for database-related errors
class DatabaseException implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  DatabaseException(this.message, [this.cause, this.stackTrace]);

  @override
  String toString() =>
      'DatabaseException: $message${cause != null ? ' (Cause: $cause)' : ''}';
}

/// Exception thrown when database initialization fails
class DatabaseInitException extends DatabaseException {
  DatabaseInitException(super.message, [super.cause, super.stackTrace]);

  @override
  String toString() =>
      'DatabaseInitException: $message${cause != null ? ' (Cause: $cause)' : ''}';
}

/// Exception thrown when a database migration fails
class MigrationException extends DatabaseException {
  final int version;

  MigrationException(this.version, String message,
      [Object? cause, StackTrace? stackTrace])
      : super(message, cause, stackTrace);

  @override
  String toString() =>
      'MigrationException (v$version): $message${cause != null ? ' (Cause: $cause)' : ''}';
}

/// Exception thrown when record is not found
class NotFoundException extends DatabaseException {
  NotFoundException(super.message);
}
