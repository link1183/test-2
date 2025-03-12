import 'dart:async';
import 'dart:io';

import 'package:backend/db/database_connection_pool.dart';
import 'package:backend/services/metrics_service.dart';
import 'package:backend/utils/logger.dart';

/// Service that monitors database health and performance
class DatabaseHealthService {
  final DatabaseConnectionPool _connectionPool;
  final MetricsService _metricsService;
  final Logger _logger = LoggerFactory.getLogger('DatabaseHealthService');

  Timer? _healthCheckTimer;
  bool _isRunning = false;

  /// Creates a new database health service
  DatabaseHealthService(this._connectionPool, this._metricsService);

  /// Check database health
  Future<Map<String, dynamic>> checkHealth() async {
    final startTime = DateTime.now();
    final metrics = _metricsService.metrics;

    late PooledDatabaseConnection connection;
    try {
      // Get a connection from the pool
      connection = await _connectionPool.getConnection();

      // Check if the database is healthy
      final isHealthy = await connection.database.isHealthy();

      // Simple query to test query performance
      final queryStart = DateTime.now();
      await connection.database.query('SELECT 1');
      final queryTime = DateTime.now().difference(queryStart).inMilliseconds;

      // Get database stats
      final stats = await connection.database.getStats();

      // Calculate response time
      final responseTime = DateTime.now().difference(startTime).inMilliseconds;

      // Record metrics
      metrics.setGauge(
          'db_health_check_response_time_ms', responseTime.toDouble());
      metrics.setGauge('db_query_time_ms', queryTime.toDouble());
      metrics.setGauge('db_size_kb', stats['size_kb'].toDouble());
      metrics.setGauge('db_active_connections',
          _connectionPool.activeConnectionCount.toDouble());
      metrics.setGauge('db_idle_connections',
          _connectionPool.idleConnectionCount.toDouble());

      if (isHealthy) {
        metrics.incrementCounter('db_health_check_success');
      } else {
        metrics.incrementCounter('db_health_check_failure');
      }

      // Log health status
      if (isHealthy) {
        _logger.debug('Database health check successful', {
          'responseTimeMs': responseTime,
          'queryTimeMs': queryTime,
          'sizeKb': stats['size_kb'],
        });
      } else {
        _logger.warning('Database health check indicates potential issues', {
          'responseTimeMs': responseTime,
          'queryTimeMs': queryTime,
          'sizeKb': stats['size_kb'],
        });
      }

      return {
        'status': isHealthy ? 'UP' : 'WARNING',
        'timestamp': DateTime.now().toIso8601String(),
        'responseTimeMs': responseTime,
        'queryTimeMs': queryTime,
        'connections': {
          'active': _connectionPool.activeConnectionCount,
          'idle': _connectionPool.idleConnectionCount,
          'total': _connectionPool.totalConnectionCount,
        },
        'stats': stats,
      };
    } catch (e, stackTrace) {
      final responseTime = DateTime.now().difference(startTime).inMilliseconds;

      metrics.incrementCounter('db_health_check_error');
      metrics.setGauge(
          'db_health_check_response_time_ms', responseTime.toDouble());

      _logger.error('Database health check failed', e, stackTrace, {
        'responseTimeMs': responseTime,
      });

      return {
        'status': 'DOWN',
        'timestamp': DateTime.now().toIso8601String(),
        'responseTimeMs': responseTime,
        'error': e.toString(),
      };
    } finally {
      try {
        await connection.release();
      } catch (e) {
        // Ignore release errors during health checks
      }
    }
  }

  /// Get database file size
  int getDatabaseFileSize() {
    try {
      final file = File(_connectionPool.config.dbPath);
      if (file.existsSync()) {
        return file.lengthSync();
      }
    } catch (e) {
      _logger.error('Failed to get database file size', e);
    }

    return 0;
  }

  /// Start periodic health checks
  void startMonitoring({Duration interval = const Duration(minutes: 5)}) {
    if (_isRunning) return;

    _isRunning = true;
    _logger.info('Starting database health monitoring',
        {'intervalMinutes': interval.inMinutes});

    // Run an initial health check
    checkHealth();

    // Schedule periodic health checks
    _healthCheckTimer = Timer.periodic(interval, (_) {
      checkHealth();
    });
  }

  /// Stop health checks
  void stopMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    _isRunning = false;
    _logger.info('Stopped database health monitoring');
  }
}
