import 'package:backend/db/database_connection_pool.dart';
import 'package:backend/middleware/auth_middleware.dart';
import 'package:backend/utils/api_response.dart';
import 'package:backend/utils/logger.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Controller that handles all administrative API endpoints.
class AdminController {
  final DatabaseConnectionPool _connectionPool;
  final AuthMiddleware _authMiddleware;
  final Logger _logger = LoggerFactory.getLogger('AdminController');

  AdminController(this._connectionPool, this._authMiddleware);

  /// Returns the router with all admin routes defined.
  Router get router {
    final router = Router();

    // Database statistics endpoint - requires admin privileges
    router.get(
        '/db-stats',
        Pipeline()
            .addMiddleware(_authMiddleware.requireAdmin)
            .addHandler(_handleGetDbStats));

    // Database backup endpoint - requires admin privileges
    router.post(
        '/db-backup',
        Pipeline()
            .addMiddleware(_authMiddleware.requireAdmin)
            .addHandler(_handleDbBackup));

    return router;
  }

  /// Handler for POST /api/admin/db-backup
  Future<Response> _handleDbBackup(Request request) async {
    try {
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final backupPath = '/data/backup_$timestamp.db';

      final connection = await _connectionPool.getConnection();

      try {
        final success = await connection.database.backup(backupPath);

        if (success) {
          return ApiResponse.ok(
              {'success': true, 'path': backupPath, 'timestamp': timestamp});
        } else {
          return ApiResponse.serverError('Backup failed');
        }
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      _logger.error('Error creating database backup', e, stackTrace);
      return ApiResponse.serverError('Error creating database backup',
          details: e.toString());
    }
  }

  /// Handler for GET /api/admin/db-stats
  Future<Response> _handleGetDbStats(Request request) async {
    try {
      final connection = await _connectionPool.getConnection();

      try {
        final stats = await connection.database.getStats();
        return ApiResponse.ok({
          'stats': stats,
          'connections': {
            'active': _connectionPool.activeConnectionCount,
            'idle': _connectionPool.idleConnectionCount,
            'total': _connectionPool.totalConnectionCount,
            'max': _connectionPool.config.maxConnections,
          }
        });
      } finally {
        await connection.release();
      }
    } catch (e, stackTrace) {
      _logger.error('Error retrieving database statistics', e, stackTrace);
      return ApiResponse.serverError('Error retrieving database statistics',
          details: e.toString());
    }
  }
}
