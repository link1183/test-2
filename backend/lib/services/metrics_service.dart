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
  final Logger _logger = LoggerFactory.getLogger('Metrics');

  /// Generate a human-readable metrics report
  String getFormattedReport() {
    final timestamp = DateTime.now();
    final metrics = getMetrics();

    final StringBuffer buffer = StringBuffer();

    // Header
    buffer.writeln('# Metrics Report - ${_formatTimestamp(timestamp)}');
    buffer.writeln('');

    // Counters section
    buffer.writeln('## Counters');
    if (metrics['counters'].isEmpty) {
      buffer.writeln('No counters recorded.');
    } else {
      final counters = Map<String, int>.from(metrics['counters']);
      final sortedCounters = counters.keys.toList()..sort();

      buffer.writeln('| Name | Value |');
      buffer.writeln('|------|-------|');
      for (final key in sortedCounters) {
        buffer.writeln('| $key | ${counters[key]} |');
      }
    }
    buffer.writeln('');

    // Gauges section
    buffer.writeln('## Gauges');
    if (metrics['gauges'].isEmpty) {
      buffer.writeln('No gauges recorded.');
    } else {
      final gauges = Map<String, double>.from(metrics['gauges']);
      final sortedGauges = gauges.keys.toList()..sort();

      buffer.writeln('| Name | Value |');
      buffer.writeln('|------|-------|');
      for (final key in sortedGauges) {
        buffer.writeln('| $key | ${gauges[key]?.toStringAsFixed(2)} |');
      }
    }
    buffer.writeln('');

    // Histograms section
    buffer.writeln('## Histograms');
    if (metrics['histograms'].isEmpty) {
      buffer.writeln('No histograms recorded.');
    } else {
      final histograms = metrics['histograms'] as Map<String, dynamic>;
      final sortedHistograms = histograms.keys.toList()..sort();

      buffer.writeln('| Name | Count | Min | Avg | Max | p50 | p95 | p99 |');
      buffer.writeln('|------|-------|-----|-----|-----|-----|-----|-----|');
      for (final key in sortedHistograms) {
        final hist = histograms[key] as Map<String, dynamic>;
        buffer.writeln(
            '| $key | ${hist['count']} | ${hist['min']} | ${(hist['avg'] as double).toStringAsFixed(2)} | ${hist['max']} | ${hist['p50']} | ${hist['p95']} | ${hist['p99']} |');
      }
    }

    return buffer.toString();
  }

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
    _logger.info('Metrics reset');
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

  /// Format timestamp for output
  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.year}-${_pad(timestamp.month)}-${_pad(timestamp.day)} '
        '${_pad(timestamp.hour)}:${_pad(timestamp.minute)}:${_pad(timestamp.second)}';
  }

  /// Zero-pad a number to width 2
  String _pad(int n) {
    return n.toString().padLeft(2, '0');
  }

  /// Calculate a percentile value from a sorted list
  int _percentile(List<int> sortedValues, double percentile) {
    if (sortedValues.isEmpty) return 0;

    final index = (sortedValues.length * percentile).floor();
    return sortedValues[index.clamp(0, sortedValues.length - 1)];
  }
}

/// Handles metrics file rotation based on file size
class MetricsRotator {
  final String metricsFilePath;
  final int maxSizeBytes;
  final int maxBackupCount;

  bool _rotating = false;
  final Logger _logger = LoggerFactory.getLogger('MetricsRotator');

  MetricsRotator({
    required this.metricsFilePath,
    required this.maxSizeBytes,
    required this.maxBackupCount,
  });

  /// Check if rotation is needed and perform it if necessary
  bool checkAndRotate() {
    // Avoid concurrent rotations
    if (_rotating) return false;

    final file = File(metricsFilePath);
    if (!file.existsSync()) return false;

    // Check current file size
    final size = file.lengthSync();
    if (size >= maxSizeBytes) {
      _rotating = true;
      try {
        _rotateMetricsFile();
        return true;
      } catch (e, stackTrace) {
        _logger.error('Failed to rotate metrics file', e, stackTrace);
        return false;
      } finally {
        _rotating = false;
      }
    }

    return false;
  }

  /// Start the rotator
  void start() {
    _logger.info('Metrics file rotation enabled', {
      'filePath': metricsFilePath,
      'maxSizeBytes': maxSizeBytes,
      'maxBackupCount': maxBackupCount
    });

    // Initial check in case the file is already too large
    checkAndRotate();
  }

  /// Stop the rotator
  void stop() {
    _logger.info('Metrics file rotation disabled');
  }

  /// Delete old backup files if we exceed maxBackupCount
  void _cleanupOldBackups() {
    try {
      final dir = Directory(File(metricsFilePath).parent.path);
      final extension = metricsFilePath.contains('.')
          ? metricsFilePath.substring(metricsFilePath.lastIndexOf('.'))
          : '';

      final baseName = extension.isNotEmpty
          ? File(metricsFilePath).uri.pathSegments.last.substring(
              0, File(metricsFilePath).uri.pathSegments.last.lastIndexOf('.'))
          : File(metricsFilePath).uri.pathSegments.last;

      // Find all backup files for this metrics file
      final backupPattern =
          RegExp('$baseName-\\d{8}-\\d{6}${RegExp.escape(extension)}');
      final backupFiles = dir
          .listSync()
          .whereType<File>()
          .where((f) => backupPattern.hasMatch(f.path))
          .toList();

      // Sort by name in descending order (newest first based on timestamp in filename)
      backupFiles.sort((a, b) => b.path.compareTo(a.path));

      // Delete oldest files beyond our limit
      if (backupFiles.length > maxBackupCount) {
        for (var i = maxBackupCount; i < backupFiles.length; i++) {
          final file = backupFiles[i];
          file.deleteSync();
          _logger.debug('Deleted old metrics backup file', {'path': file.path});
        }

        _logger.info('Cleaned up old metrics backup files', {
          'deleted': backupFiles.length - maxBackupCount,
          'remaining': maxBackupCount
        });
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to clean up old metrics backups', e, stackTrace);
    }
  }

  /// Zero-pad a number to width 2
  String _pad(int n) {
    return n.toString().padLeft(2, '0');
  }

  /// Perform metrics file rotation
  void _rotateMetricsFile() {
    try {
      final now = DateTime.now();
      final timestamp =
          '${now.year}${_pad(now.month)}${_pad(now.day)}-${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';

      final file = File(metricsFilePath);
      final extension = metricsFilePath.contains('.')
          ? metricsFilePath.substring(metricsFilePath.lastIndexOf('.'))
          : '';

      final baseName = extension.isNotEmpty
          ? metricsFilePath.substring(0, metricsFilePath.lastIndexOf('.'))
          : metricsFilePath;

      final backupFileName = '$baseName-$timestamp$extension';

      // Copy current metrics to backup file
      file.copySync(backupFileName);

      // Clear the current metrics file
      file.writeAsStringSync('');

      _logger.info('Metrics file rotated', {
        'oldSize': file.lengthSync(),
        'backupFile': backupFileName,
      });

      // Delete old backup files if we have too many
      _cleanupOldBackups();
    } catch (e, stackTrace) {
      _logger.error('Error during metrics file rotation', e, stackTrace);
      rethrow; // Rethrow to let caller know rotation failed
    }
  }
}

/// Service for collecting and exporting application metrics
class MetricsService {
  static final MetricsService instance = MetricsService._();

  final Metrics metrics = Metrics();
  final Logger _logger = LoggerFactory.getLogger('MetricsService');
  Timer? _exportTimer;
  MetricsRotator? _rotator;
  bool _useFormattedOutput = false;

  MetricsService._();

  /// Dispose resources used by the metrics service
  void dispose() {
    _exportTimer?.cancel();
    _exportTimer = null;
    _rotator?.stop();
    _rotator = null;
    _logger.info('Metrics service disposed');
  }

  /// Start exporting metrics periodically to a file
  void startPeriodicExport({
    Duration interval = const Duration(minutes: 1),
    String? filePath,
    bool useFormattedOutput = false,
    bool enableRotation = false,
    int maxFileSizeBytes = 10 * 1024 * 1024, // 10MB default
    int maxBackupCount = 5,
  }) {
    _exportTimer?.cancel();
    _rotator?.stop();

    _useFormattedOutput = useFormattedOutput;

    if (filePath != null) {
      _logger.info('Starting periodic metrics export', {
        'filePath': filePath,
        'intervalMs': interval.inMilliseconds,
        'formattedOutput': useFormattedOutput,
        'rotation': enableRotation ? 'enabled' : 'disabled',
      });

      // Create directory if it doesn't exist
      final dir = Directory(File(filePath).parent.path);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      // Set up rotation if enabled
      if (enableRotation) {
        _rotator = MetricsRotator(
          metricsFilePath: filePath,
          maxSizeBytes: maxFileSizeBytes,
          maxBackupCount: maxBackupCount,
        );
        _rotator!.start();
      }

      _exportTimer = Timer.periodic(interval, (_) {
        try {
          final file = File(filePath);

          String data;
          if (_useFormattedOutput) {
            data = metrics.getFormattedReport();
          } else {
            data = json.encode(metrics.getMetrics());
          }

          file.writeAsStringSync(data);

          // Check for rotation after write
          if (enableRotation) {
            _rotator!.checkAndRotate();
          }

          _logger.debug('Metrics exported to file');
        } catch (e, stackTrace) {
          _logger.error('Failed to export metrics', e, stackTrace,
              {'filePath': filePath});
        }
      });
    }
  }
}

