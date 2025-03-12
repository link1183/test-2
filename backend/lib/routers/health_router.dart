import 'dart:convert';
import 'dart:io';

import 'package:backend/db/database_connection_pool.dart';
import 'package:backend/middleware/auth_middleware.dart';
import 'package:backend/services/database_health_service.dart';
import 'package:backend/services/metrics_service.dart';
import 'package:backend/utils/logger.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Router that provides health and metrics endpoints for monitoring the application
class HealthRouter {
  final DatabaseConnectionPool _connectionPool;
  final Logger _logger = LoggerFactory.getLogger('HealthRouter');
  final AuthMiddleware _authMiddleware;
  late final DatabaseHealthService _healthService;

  HealthRouter(this._connectionPool, this._authMiddleware) {
    _healthService =
        DatabaseHealthService(_connectionPool, MetricsService.instance);
  }

  Router get router {
    final router = Router();

    // Basic health check endpoint - unauthenticated
    router.get('/health', _handleBasicHealth);

    // Detailed health check - authenticated + admin only
    router.get(
        '/health/detailed',
        Pipeline()
            .addMiddleware(_authMiddleware.requireAdmin)
            .addHandler(_handleDetailedHealth));

    // Metrics endpoint - authenticated + admin only
    router.get(
        '/metrics',
        Pipeline()
            .addMiddleware(_authMiddleware.requireAdmin)
            .addHandler(_handleMetrics));

    return router;
  }

  /// Handle basic health check request
  Future<Response> _handleBasicHealth(Request request) async {
    try {
      // Simple DB connectivity check
      final healthCheck = await _healthService.checkHealth();

      final health = {
        'status': healthCheck['status'],
        'timestamp': DateTime.now().toIso8601String(),
      };

      return Response.ok(
        json.encode(health),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.error('Health check failed', e, stackTrace);
      return Response.internalServerError(
        body: json.encode({
          'status': 'DOWN',
          'error': 'Health check failed',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  /// Handle detailed health check request
  Future<Response> _handleDetailedHealth(Request request) async {
    try {
      // Detailed database health check
      final healthCheck = await _healthService.checkHealth();

      // System resources
      final memoryUsage = ProcessInfo.currentRss;
      final maxRss = ProcessInfo.maxRss;

      final health = {
        'status': healthCheck['status'],
        'timestamp': DateTime.now().toIso8601String(),
        'memory': {
          'currentRssBytes': memoryUsage,
          'maxRssBytes': maxRss,
          'currentRssMb': memoryUsage ~/ (1024 * 1024),
          'maxRssMb': maxRss ~/ (1024 * 1024),
        },
        'database': healthCheck,
        'connections': {
          'active': _connectionPool.activeConnectionCount,
          'idle': _connectionPool.idleConnectionCount,
          'total': _connectionPool.totalConnectionCount,
          'max': _connectionPool.config.maxConnections,
        }
      };

      return Response.ok(
        json.encode(health),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.error('Detailed health check failed', e, stackTrace);
      return Response.internalServerError(
        body: json.encode({
          'status': 'DOWN',
          'error': 'Detailed health check failed',
          'details': e.toString(),
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  /// Handle metrics request
  Future<Response> _handleMetrics(Request request) async {
    try {
      final metrics = MetricsService.instance.metrics.getMetrics();

      return Response.ok(
        json.encode(metrics),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stackTrace) {
      _logger.error('Metrics request failed', e, stackTrace);
      return Response.internalServerError(
        body: json.encode({
          'error': 'Failed to retrieve metrics',
          'details': e.toString(),
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }
}

