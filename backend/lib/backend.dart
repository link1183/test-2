import 'dart:async';
import 'dart:io';

import 'package:backend/db/api.dart';
import 'package:backend/db/database.dart';
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

void main() async {
  HttpServer? server;

  Directory('/data/logs').createSync(recursive: true);
  Directory('/data/metrics').createSync(recursive: true);

  // Configure the logger
  LoggerFactory.configure(
    minimumLevel: LogLevel.debug,
    logFilePath: '/data/logs/application.log',
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

    // Initialize metrics service
    MetricsService.instance.startPeriodicExport(
      interval: Duration(minutes: 1),
      filePath: '/data/metrics/metrics.json',
    );

    // Create API with dependencies
    final authService = ServiceLocator.instance.get<AuthService>();
    final api = Api(authService: authService);

    // Create the health router
    final db = ServiceLocator.instance.get<AppDatabase>();
    final healthRouter = HealthRouter(db, AuthMiddleware(authService));

    // Set up the router and mount API routes
    final app = Router();
    app.mount('/api/', api.router.call);
    app.mount('/api/', healthRouter.router.call);

    // Create the request pipeline with middleware
    final handler = Pipeline()
        .addMiddleware(logRequests())
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

Future<void> _shutdown(HttpServer? server, Logger logger) async {
  logger.info('Shutting down server...');

  if (server != null) {
    await server.close(force: false);
    logger.info('HTTP server closed');
  }

  // Clean up services
  try {
    await ServiceLocator.instance.dispose();
    logger.info('Services disposed');

    MetricsService.instance.dispose();
    logger.info('Metrics service disposed');

    LoggerFactory.closeAll();
  } catch (e, stackTrace) {
    logger.error('Error during shutdown', e, stackTrace);
  }

  logger.info('Shutdown complete');
  exit(0);
}
