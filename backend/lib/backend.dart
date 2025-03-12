import 'dart:async';
import 'dart:io';

import 'package:backend/db/api.dart';
import 'package:backend/db/database_connection_pool.dart';
import 'package:backend/db/database_seeder.dart';
import 'package:backend/di/service_locator.dart';
import 'package:backend/middleware/auth_middleware.dart';
import 'package:backend/middleware/metrics_middleware.dart';
import 'package:backend/middleware/request_tracking_middleware.dart';
import 'package:backend/routers/health_router.dart';
import 'package:backend/services/auth_service.dart';
import 'package:backend/services/metrics_service.dart';
import 'package:backend/utils/logger.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';

/// Application entry point
void main() async {
  HttpServer? server;

  // Configure the logger
  Directory('/data/logs').createSync(recursive: true);
  Directory('/data/metrics').createSync(recursive: true);

  LoggerFactory.configure(
    minimumLevel: LogLevel.debug,
    logFilePath: '/data/logs/application.log',
    useJsonFormat: false,
    enableRotation: true,
    maxLogSizeBytes: 10 * 1024 * 1024, // 10MB
    maxBackupCount: 5,
    checkIntervalSeconds: 600,
  );

  final logger = LoggerFactory.getLogger('Main');
  logger.info('Starting application...');

  // Set up signal handling for graceful shutdown
  ProcessSignal.sigint.watch().listen((_) async {
    logger.info('Received SIGINT signal, shutting down...');
    await _shutdown(server, logger);
  });

  ProcessSignal.sigterm.watch().listen((_) async {
    logger.info('Received SIGTERM signal, shutting down...');
    await _shutdown(server, logger);
  });

  try {
    // Initialize service locator
    logger.info('Initializing service locator...');
    await ServiceLocator.instance.initialize();

    // Seed development data if environment variable is set
    if (Platform.environment['SEED_DEV_DATA'] == 'true') {
      logger.info('Seeding development data...');

      final connectionPool =
          ServiceLocator.instance.get<DatabaseConnectionPool>();
      final seeder = DevelopmentSeeder();

      await seeder.seed(connectionPool);
    }

    // Create API with dependencies
    final authService = ServiceLocator.instance.get<AuthService>();
    final authMiddleware = AuthMiddleware(authService);

    // Set up the router
    final app = Router();

    // Add health routes
    final connectionPool =
        ServiceLocator.instance.get<DatabaseConnectionPool>();
    final healthRouter = HealthRouter(connectionPool, authMiddleware);
    app.mount('/api/health/', healthRouter.router.call);

    // Set up API routes
    final api = Api(authService: authService);
    app.mount('/api/', api.router.call);

    // Create the request pipeline with middleware
    final handler = Pipeline()
        .addMiddleware(corsHeaders())
        .addMiddleware(requestTrackingMiddleware())
        .addMiddleware(metricsMiddleware())
        .addHandler(app.call);

    // Start the server
    logger.info('Starting HTTP server...');
    server = await io.serve(handler, '0.0.0.0', 8080);
    logger.info(
        'Server running', {'host': server.address.host, 'port': server.port});

    // Update metrics with server info
    MetricsService.instance.metrics.setGauge(
        'server_start_time', DateTime.now().millisecondsSinceEpoch.toDouble());
  } catch (e, stackTrace) {
    logger.critical('Failed to start server', e, stackTrace);
    await _shutdown(server, logger);
    exit(1);
  }
}

/// Gracefully shut down the application
Future<void> _shutdown(HttpServer? server, Logger logger) async {
  logger.info('Shutting down server...');

  if (server != null) {
    await server.close(force: false);
    logger.info('HTTP server closed');
  }

  // Clean up services
  try {
    await ServiceLocator.instance.dispose();
    logger.info('All services disposed');
  } catch (e, stackTrace) {
    logger.error('Error during shutdown', e, stackTrace);
  }

  logger.info('Shutdown complete');
  exit(0);
}

