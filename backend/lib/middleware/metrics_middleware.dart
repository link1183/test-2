import 'package:backend/services/metrics_service.dart';
import 'package:shelf/shelf.dart';

/// Middleware that collects metrics about requests and responses
///
/// This middleware:
/// - Counts total requests by path and method
/// - Tracks response status codes
/// - Measures request durations
/// - Updates active request count gauge
Middleware metricsMiddleware() {
  final metrics = MetricsService.instance.metrics;

  return (Handler innerHandler) {
    return (Request request) async {
      final path = _normalizePath(request.url.path);
      final method = request.method;

      // Increment request counter
      metrics.incrementCounter('http_requests_total');
      metrics.incrementCounter('http_requests_${method.toLowerCase()}');
      metrics.incrementCounter(
          'http_requests_path_${path}_${method.toLowerCase()}');

      // Increment active requests gauge
      metrics.incrementCounter('http_requests_active');

      // Start timing the request
      final timer = metrics.startTimer('http_request_duration');

      try {
        final response = await innerHandler(request);

        // Record response metrics
        final statusCode = response.statusCode;
        metrics.incrementCounter('http_responses_total');
        metrics.incrementCounter('http_responses_$statusCode');
        metrics.incrementCounter('http_responses_${statusCode ~/ 100}xx');

        // Stop timer and record duration
        timer.stop();
        metrics.recordValue(
            'http_request_duration_milliseconds', timer.elapsedMilliseconds);
        metrics.recordValue(
            'http_request_duration_path_${path}_${method.toLowerCase()}_milliseconds',
            timer.elapsedMilliseconds);

        // Decrement active requests gauge
        metrics.incrementCounter('http_requests_active', -1);

        return response;
      } catch (e) {
        // Record error metrics
        metrics.incrementCounter('http_errors_total');

        // Stop timer
        timer.stop();
        metrics.recordValue('http_request_error_duration_milliseconds',
            timer.elapsedMilliseconds);

        // Decrement active requests gauge
        metrics.incrementCounter('http_requests_active', -1);

        rethrow;
      }
    };
  };
}

/// Normalize a path to make it suitable for use in metric names
///
/// This removes ID segments and query parameters to prevent metric explosion
String _normalizePath(String path) {
  // Remove trailing slash
  if (path.endsWith('/') && path.length > 1) {
    path = path.substring(0, path.length - 1);
  }

  // Split path into segments
  final segments =
      path.split('/').where((segment) => segment.isNotEmpty).toList();

  // Replace numeric or UUID segments with {id}
  for (var i = 0; i < segments.length; i++) {
    final segment = segments[i];

    // Check if segment is numeric or UUID-like
    if (RegExp(r'^\d+$').hasMatch(segment) ||
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
            .hasMatch(segment)) {
      segments[i] = '{id}';
    }
  }

  // Rejoin path
  return segments.join('_');
}
