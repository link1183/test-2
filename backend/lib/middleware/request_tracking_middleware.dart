import 'package:backend/utils/logger.dart';
import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';

/// Middleware that adds request tracking and logging capabilities
///
/// This middleware:
/// - Generates a unique request ID for each request
/// - Logs the start and completion of each request
/// - Tracks request durations
/// - Adds the request ID to response headers
Middleware requestTrackingMiddleware() {
  final logger = LoggerFactory.getLogger('RequestTracker');

  return (Handler innerHandler) {
    return (Request request) async {
      final requestId = Uuid().v4();
      final path = request.url.path;
      final method = request.method;
      final startTime = DateTime.now();

      // Add request tracking headers
      final updatedRequest = request.change(headers: {
        ...request.headers,
        'x-request-id': requestId,
      });

      logger.info('Request started', {
        'requestId': requestId,
        'method': method,
        'path': path,
        'remoteAddress': request.headers['x-forwarded-for'] ??
            request.headers['x-real-ip'] ??
            'unknown',
        'userAgent': request.headers['user-agent'] ?? 'unknown',
      });

      try {
        final response = await innerHandler(updatedRequest);

        final duration = DateTime.now().difference(startTime).inMilliseconds;

        // Add request ID to response headers
        final updatedResponse = response.change(headers: {
          ...response.headers,
          'x-request-id': requestId,
        });

        logger.info('Request completed', {
          'requestId': requestId,
          'method': method,
          'path': path,
          'statusCode': response.statusCode,
          'durationMs': duration,
        });

        return updatedResponse;
      } catch (e, stackTrace) {
        final duration = DateTime.now().difference(startTime).inMilliseconds;

        logger.error('Request failed', e, stackTrace, {
          'requestId': requestId,
          'method': method,
          'path': path,
          'durationMs': duration,
        });

        rethrow;
      }
    };
  };
}
