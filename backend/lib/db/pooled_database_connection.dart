import 'package:backend/db/database_connection_pool.dart';
import 'package:backend/db/database_interface.dart';

/// A pooled database connection
class PooledDatabaseConnection {
  final int id;
  final DatabaseInterface database;
  final DatabaseConnectionPool pool;
  bool _released = false;
  DateTime _lastUsed = DateTime.now();

  PooledDatabaseConnection(this.id, this.database, this.pool);

  /// Get the last time this connection was used
  DateTime get lastUsed => _lastUsed;

  /// Releases the connection back to the pool
  ///
  /// If the connection is already released, the method will just return
  /// without attempting to release it again.
  Future<void> release() async {
    if (!_released) {
      _released = true;
      await pool.releaseConnection(id);
    }
  }

  /// For internal use - resets the released state when reusing a connection
  void resetReleaseState() {
    _released = false;
  }

  /// Updates the last used timestamp
  void updateLastUsed() {
    _lastUsed = DateTime.now();
  }
}
