import 'dart:async';
import 'dart:math';

import 'package:backend/db/database_config.dart';
import 'package:backend/db/database_exceptions.dart';
import 'package:backend/db/database_interface.dart';
import 'package:backend/db/sqlite_database.dart';
import 'package:backend/utils/logger.dart';

/// A pool of database connections
class DatabaseConnectionPool {
  final DatabaseConfig config;
  final Logger _logger = LoggerFactory.getLogger('DatabaseConnectionPool');

  final List<PooledDatabaseConnection> _availableConnections = [];
  final Map<int, PooledDatabaseConnection> _inUseConnections = {};
  int _lastId = 0;
  Timer? _idleConnectionTimer;
  bool _shuttingDown = false;

  /// Creates a connection pool with the specified configuration
  DatabaseConnectionPool(this.config) {
    // Start the idle connection cleanup timer
    _idleConnectionTimer =
        Timer.periodic(Duration(minutes: 5), (_) => _cleanupIdleConnections());
  }

  /// Gets the current number of active connections
  int get activeConnectionCount => _inUseConnections.length;

  /// Gets the current number of idle connections
  int get idleConnectionCount => _availableConnections.length;

  /// Gets the total number of connections in the pool
  int get totalConnectionCount => activeConnectionCount + idleConnectionCount;

  /// Gets a connection from the pool
  Future<PooledDatabaseConnection> getConnection() async {
    if (_shuttingDown) {
      throw ConnectionException('Connection pool is shutting down');
    }

    if (_inUseConnections.length >= config.maxConnections * 0.9) {
      _logger.warning('Connection pool nearly exhausted', {
        'active': _inUseConnections.length,
        'idle': _availableConnections.length,
        'max': config.maxConnections,
      });

      _logger.debug('Connection request stack trace',
          {'trace': StackTrace.current.toString()});
    }

    if (_availableConnections.isNotEmpty) {
      final connection = _availableConnections.removeLast();
      connection.updateLastUsed();
      _inUseConnections[connection.id] = connection;
      return connection;
    }

    if (_inUseConnections.length >= config.maxConnections) {
      throw ConnectionException(
          'Maximum database connections reached (${config.maxConnections})');
    }

    // Create new connection
    try {
      final db = SqliteDatabase(config);
      await db.initialize();

      final id = ++_lastId;
      final connection = PooledDatabaseConnection(id, db, this);
      _inUseConnections[id] = connection;

      _logger.debug('Created new database connection',
          {'id': id, 'total': totalConnectionCount});

      return connection;
    } catch (e, stackTrace) {
      _logger.error('Failed to create database connection', e, stackTrace);
      throw ConnectionException(
          'Failed to create database connection', e, stackTrace);
    }
  }

  /// Releases a connection back to the pool
  Future<void> releaseConnection(int id) async {
    final connection = _inUseConnections.remove(id);

    if (connection != null) {
      connection.updateLastUsed();

      if (_shuttingDown) {
        await _closeConnection(connection);
      } else {
        _availableConnections.add(connection);
      }

      _logger.debug('Released database connection', {
        'id': id,
        'active': activeConnectionCount,
        'idle': idleConnectionCount
      });
    }
  }

  /// Shuts down the connection pool
  Future<void> shutdown() async {
    _logger.info('Shutting down database connection pool');
    _shuttingDown = true;

    // Cancel the idle connection cleanup timer
    _idleConnectionTimer?.cancel();
    _idleConnectionTimer = null;

    // Close all connections
    final allConnections = [
      ..._availableConnections,
      ..._inUseConnections.values
    ];
    _availableConnections.clear();
    _inUseConnections.clear();

    for (final connection in allConnections) {
      await _closeConnection(connection);
    }

    _logger.info('Database connection pool shut down successfully');
  }

  /// Cleans up idle connections that haven't been used for a while
  void _cleanupIdleConnections() {
    if (_shuttingDown) return;

    final now = DateTime.now();
    final idleTimeout = Duration(minutes: 10);

    // Only keep a minimum number of idle connections around
    final maxIdleConnections = max(1, config.maxConnections ~/ 4);

    // Log the current connection status
    _logger.debug('Connection pool status check', {
      'active': _inUseConnections.length,
      'idle': _availableConnections.length,
      'total': totalConnectionCount,
      'max': config.maxConnections,
    });

    // If we have more idle connections than needed, close the oldest ones
    if (_availableConnections.length > maxIdleConnections) {
      // Sort by last used time (oldest first)
      _availableConnections.sort((a, b) => a.lastUsed.compareTo(b.lastUsed));

      // Get connections to close
      final connectionsToClose = _availableConnections
          .take(_availableConnections.length - maxIdleConnections)
          .toList();

      // Remove from available connections
      _availableConnections
          .removeWhere((c) => connectionsToClose.any((cc) => cc.id == c.id));

      // Close the connections
      for (final connection in connectionsToClose) {
        _closeConnection(connection);
      }

      _logger.debug(
          'Closed ${connectionsToClose.length} excess idle connections',
          {'remaining': _availableConnections.length});
    }

    // Close any idle connections that haven't been used for a while
    final oldIdleConnections = _availableConnections
        .where((c) => now.difference(c.lastUsed) > idleTimeout)
        .toList();

    if (oldIdleConnections.isNotEmpty) {
      // Make sure we keep at least one connection in the pool
      if (_availableConnections.length <= 1) {
        return;
      }

      // Remove from available connections
      _availableConnections
          .removeWhere((c) => oldIdleConnections.any((cc) => cc.id == c.id));

      // Close the connections
      for (final connection in oldIdleConnections) {
        _closeConnection(connection);
      }

      _logger.debug(
          'Closed ${oldIdleConnections.length} idle connections due to timeout',
          {'remaining': _availableConnections.length});
    }
  }

  /// Closes a connection
  Future<void> _closeConnection(PooledDatabaseConnection connection) async {
    try {
      await connection.database.close();
      _logger.debug('Closed database connection', {'id': connection.id});
    } catch (e, stackTrace) {
      _logger.error('Error closing database connection', e, stackTrace);
    }
  }
}

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
  Future<void> release() async {
    if (!_released) {
      await pool.releaseConnection(id);
      _released = true;
    } else {
      pool._logger.warning(
          'Attempt to release already released connection', {'id': id});
    }
  }

  /// Updates the last used timestamp
  void updateLastUsed() {
    _lastUsed = DateTime.now();
  }
}
