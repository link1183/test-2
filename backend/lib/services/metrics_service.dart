import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:backend/utils/logger.dart';

/// Tracks various application metrics for monitoring and performance analysis
class Metrics {
  final Map<String, int> _counters = {};
  final Map<String, List<int>> _histograms = {};
  final Map<String, Stopwatch> _timers = {};
  final Map<String, double> _gauges = {};

  /// Get all metrics in a structured format
  Map<String, dynamic> getMetrics() {
    final result = <String, dynamic>{
      'counters': Map.from(_counters),
      'gauges': Map.from(_gauges),
      'histograms': {},
      'timestamp': DateTime.now().toIso8601String(),
    };

    for (final entry in _histograms.entries) {
      final values = entry.value;
      if (values.isEmpty) continue;

      values.sort();
      final sum = values.reduce((a, b) => a + b);

      result['histograms'][entry.key] = {
        'count': values.length,
        'min': values.first,
        'max': values.last,
        'avg': sum / values.length,
        'p50': _percentile(values, 0.5),
        'p90': _percentile(values, 0.9),
        'p95': _percentile(values, 0.95),
        'p99': _percentile(values, 0.99),
      };
    }

    return result;
  }

  /// Increment a counter metric
  void incrementCounter(String name, [int value = 1]) {
    _counters[name] = (_counters[name] ?? 0) + value;
  }

  /// Record a value for a histogram metric
  void recordValue(String name, int value) {
    _histograms.putIfAbsent(name, () => []).add(value);

    // Keep histograms from growing too large
    final values = _histograms[name]!;
    if (values.length > 1000) {
      _histograms[name] = values.sublist(values.length - 1000);
    }
  }

  /// Reset all metrics
  void reset() {
    _counters.clear();
    _histograms.clear();
    _timers.clear();
    _gauges.clear();
  }

  /// Set a gauge to a specific value
  void setGauge(String name, double value) {
    _gauges[name] = value;
  }

  /// Start a timer for tracking durations
  Stopwatch startTimer(String name) {
    final timer = Stopwatch()..start();
    _timers[name] = timer;
    return timer;
  }

  /// Stop a timer and record its duration
  void stopTimer(String name) {
    final timer = _timers.remove(name);
    if (timer != null) {
      timer.stop();
      recordValue('${name}_milliseconds', timer.elapsedMilliseconds);
    }
  }

  /// Calculate a percentile value from a sorted list
  int _percentile(List<int> sortedValues, double percentile) {
    if (sortedValues.isEmpty) return 0;

    final index = (sortedValues.length * percentile).floor();
    return sortedValues[index.clamp(0, sortedValues.length - 1)];
  }
}

/// Service for collecting and exporting application metrics
class MetricsService {
  static final MetricsService instance = MetricsService._();

  final Metrics metrics = Metrics();
  final Logger _logger = LoggerFactory.getLogger('MetricsService');
  Timer? _exportTimer;

  MetricsService._();

  /// Dispose resources used by the metrics service
  void dispose() {
    _exportTimer?.cancel();
    _exportTimer = null;
    _logger.info('Metrics service disposed');
  }

  /// Start exporting metrics periodically to a file
  void startPeriodicExport({
    Duration interval = const Duration(minutes: 1),
    String? filePath,
  }) {
    _exportTimer?.cancel();

    if (filePath != null) {
      _logger.info('Starting periodic metrics export',
          {'filePath': filePath, 'intervalMs': interval.inMilliseconds});

      _exportTimer = Timer.periodic(interval, (_) {
        try {
          final file = File(filePath);
          final data = json.encode(metrics.getMetrics());
          file.writeAsStringSync(data);
          _logger.debug('Metrics exported to file');
        } catch (e, stackTrace) {
          _logger.error('Failed to export metrics', e, stackTrace,
              {'filePath': filePath});
        }
      });
    }
  }
}
