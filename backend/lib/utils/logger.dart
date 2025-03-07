import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A structured logging utility that supports multiple output destinations,
/// different log levels, and automatic log rotation.
class Logger {
  /// The minimum log level that will be processed
  static LogLevel minimumLevel = LogLevel.info;

  /// Whether to use JSON format for file logs (false for more readable format)
  static bool useJsonFormatInFile = false;

  final String module;
  final bool enableConsole;
  final String? _logFilePath;
  IOSink? _logFile;
  final LogRotator? _rotator;

  /// Create a new logger for the specified module
  ///
  /// Parameters:
  /// - module: The name of the module this logger is for
  /// - enableConsole: Whether to print logs to the console
  /// - logFilePath: Optional path to a file to write logs to
  /// - enableRotation: Whether to enable log rotation
  /// - maxLogSizeBytes: Maximum size of log file before rotation
  /// - maxBackupCount: Maximum number of backup files to keep
  /// - checkIntervalSeconds: How often to check if rotation is needed
  factory Logger(
    String module, {
    bool enableConsole = true,
    String? logFilePath,
    bool enableRotation = false,
    int maxLogSizeBytes = 10 * 1024 * 1024, // Default 10MB
    int maxBackupCount = 5,
    int checkIntervalSeconds = 600, // Default 10 minutes
  }) {
    IOSink? logFile;
    LogRotator? rotator;

    if (logFilePath != null) {
      // Create directory if it doesn't exist
      final dir = Directory(File(logFilePath).parent.path);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      final file = File(logFilePath);
      logFile = file.openWrite(mode: FileMode.append);

      // Set up rotation if enabled
      if (enableRotation) {
        rotator = LogRotator(
          logFilePath: logFilePath,
          maxSizeBytes: maxLogSizeBytes,
          maxBackupCount: maxBackupCount,
          checkIntervalSeconds: checkIntervalSeconds,
        );
      }
    }

    return Logger._internal(
        module, enableConsole, logFilePath, logFile, rotator);
  }

  Logger._internal(this.module, this.enableConsole, this._logFilePath,
      this._logFile, this._rotator) {
    // Start rotation timer if rotator is configured
    _rotator?.start(this);
  }

  /// Close the logger and any associated resources
  void close() {
    _logFile?.close();
    _logFile = null;
    _rotator?.stop();
  }

  /// Log a critical message
  void critical(String message,
      [Object? error, StackTrace? stackTrace, Map<String, dynamic>? data]) {
    final enrichedData =
        data != null ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    if (error != null) {
      enrichedData['error'] = error.toString();
    }
    if (stackTrace != null) {
      enrichedData['stackTrace'] = stackTrace.toString();
    }

    _log(LogLevel.critical, message, enrichedData);
  }

  /// Log a debug message
  void debug(String message, [Map<String, dynamic>? data]) {
    _log(LogLevel.debug, message, data);
  }

  /// Log an error message with optional error object and stack trace
  void error(String message,
      [Object? error, StackTrace? stackTrace, Map<String, dynamic>? data]) {
    final enrichedData =
        data != null ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    if (error != null) {
      enrichedData['error'] = error.toString();
    }
    if (stackTrace != null) {
      enrichedData['stackTrace'] = stackTrace.toString();
    }

    _log(LogLevel.error, message, enrichedData);
  }

  /// Log an informational message
  void info(String message, [Map<String, dynamic>? data]) {
    _log(LogLevel.info, message, data);
  }

  /// Log a warning message
  void warning(String message, [Map<String, dynamic>? data]) {
    _log(LogLevel.warning, message, data);
  }

  /// Format timestamp for output
  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.year}-${_pad(timestamp.month)}-${_pad(timestamp.day)} '
        '${_pad(timestamp.hour)}:${_pad(timestamp.minute)}:${_pad(timestamp.second)}.${_pad(timestamp.millisecond, 3)}';
  }

  /// Internal method to process and output logs
  /// Internal method to process and output logs
  void _log(LogLevel level, String message, [Map<String, dynamic>? data]) {
    if (level.index < minimumLevel.index) return;

    final timestamp = DateTime.now();
    final formattedTime = _formatTimestamp(timestamp);

    // Create the log entry
    final logEntry = {
      'timestamp': timestamp.toIso8601String(),
      'level': level.toString().split('.').last,
      'module': module,
      'message': message,
      if (data != null) 'data': data,
    };

    // Save to file if a log file is configured
    if (_logFile != null && _logFilePath != null) {
      try {
        if (useJsonFormatInFile) {
          // Use JSON format (machine-readable)
          final logString = json.encode(logEntry);
          _logFile!.writeln(logString);
        } else {
          // Use structured text format (human-readable)
          _writeStructuredLog(_logFile!, level, formattedTime, message, data);
        }

        // Force flush to disk - helps with more accurate file size checks for rotation
        _logFile!.flush();
      } catch (e) {
        // Handle StreamSink error and try to recover
        if (e.toString().contains('StreamSink is bound to a stream')) {
          try {
            // Close the current file handle (ignore errors)
            try {
              _logFile?.close();
            } catch (_) {}

            // Reopen the log file
            _logFile = File(_logFilePath).openWrite(mode: FileMode.append);

            // Try writing again
            if (useJsonFormatInFile) {
              final logString = json.encode(logEntry);
              _logFile!.writeln(logString);
            } else {
              _writeStructuredLog(
                  _logFile!, level, formattedTime, message, data);
            }

            // Force flush
            _logFile!.flush();
          } catch (reopenError) {
            // If reopening fails, we'll just continue with console output
            if (enableConsole) {
              print('Failed to reopen log file: $reopenError');
            }
          }
        } else {
          // If it's a different error, just report it
          if (enableConsole) {
            print('Failed to write to log file: $e');
          }
        }
      }
    }

    // Console output in a readable format
    if (enableConsole) {
      _printConsoleLog(level, formattedTime, message, data);
    }
  }

  /// Zero-pad a number to a specified width
  String _pad(int n, [int width = 2]) {
    return n.toString().padLeft(width, '0');
  }

  /// Print a formatted log message to the console
  void _printConsoleLog(LogLevel level, String timestamp, String message,
      Map<String, dynamic>? data) {
    // Color codes for different log levels
    final Map<LogLevel, String> colors = {
      LogLevel.debug: '\x1B[90m', // Bright black (gray)
      LogLevel.info: '\x1B[32m', // Green
      LogLevel.warning: '\x1B[33m', // Yellow
      LogLevel.error: '\x1B[31m', // Red
      LogLevel.critical: '\x1B[35m', // Magenta
    };

    // Level indicators with padding for alignment
    final Map<LogLevel, String> levelLabels = {
      LogLevel.debug: 'DEBUG  ',
      LogLevel.info: 'INFO   ',
      LogLevel.warning: 'WARNING',
      LogLevel.error: 'ERROR  ',
      LogLevel.critical: 'CRITICAL',
    };

    final colorCode = colors[level] ?? '\x1B[0m';
    final levelLabel = levelLabels[level] ?? level.toString();
    final resetColor = '\x1B[0m';

    // Base log line
    String logLine =
        '$colorCode[$timestamp] $levelLabel [$module] $message$resetColor';
    print(logLine);

    // If there's additional data, print it indented on subsequent lines
    if (data != null && data.isNotEmpty) {
      const indent =
          '                                   '; // Adjust to match the width of timestamp + level + module
      data.forEach((key, value) {
        if (value is Map || value is List) {
          // Format as pretty JSON if it's a complex object
          String prettyJson = const JsonEncoder.withIndent('  ').convert(value);
          // Split the pretty JSON into lines
          List<String> lines = prettyJson.split('\n');

          print('$colorCode$indent$key: ${lines[0]}$resetColor');
          for (int i = 1; i < lines.length; i++) {
            print('$colorCode$indent     ${lines[i]}$resetColor');
          }
        } else if (key == 'stackTrace' && value.toString().contains('\n')) {
          // Special handling for stack traces
          final stackLines = value.toString().split('\n');
          print('$colorCode$indent$key:$resetColor');
          for (var line in stackLines) {
            if (line.isNotEmpty) {
              print('$colorCode$indent     $line$resetColor');
            }
          }
        } else {
          // Simple key-value for primitive types
          print('$colorCode$indent$key: $value$resetColor');
        }
      });
    }
  }

  /// Reopens the log file (used after rotation)
  void _reopenLogFile() {
    if (_logFilePath != null) {
      try {
        // Close existing file if open
        _logFile?.close();

        // Open a new file
        final file = File(_logFilePath);
        _logFile = file.openWrite(mode: FileMode.append);

        info('Log file rotated, new log file opened');
      } catch (e, stackTrace) {
        // If we can't reopen the log file, at least try to output to console
        final message = 'Failed to reopen log file: $e';
        if (enableConsole) {
          print(message);
          print(stackTrace);
        }
      }
    }
  }

  /// Write a structured log entry to file
  void _writeStructuredLog(IOSink sink, LogLevel level, String timestamp,
      String message, Map<String, dynamic>? data) {
    final levelStr = level.toString().split('.').last.toUpperCase().padRight(8);

    // Write the main log line
    sink.write('[$timestamp] $levelStr [$module] $message');

    // If there's no additional data, end the line
    if (data == null || data.isEmpty) {
      sink.writeln();
      return;
    }

    // If there's just one simple property, add it to the same line
    if (data.length == 1 &&
        (data.values.first is! Map) &&
        (data.values.first is! List)) {
      final entry = data.entries.first;
      sink.writeln(' | ${entry.key}: ${entry.value}');
      return;
    }

    // Otherwise, start a new line and add data as indented properties
    sink.writeln();

    // Add data properties on separate lines with indentation
    data.forEach((key, value) {
      if (value is Map || value is List) {
        // For complex objects, use compact JSON
        sink.writeln('    $key: ${json.encode(value)}');
      } else if (key == 'stackTrace' && value.toString().contains('\n')) {
        // Special handling for stack traces
        final stackLines = value.toString().split('\n');
        sink.writeln('    $key:');
        for (var line in stackLines) {
          if (line.isNotEmpty) {
            sink.writeln('        $line');
          }
        }
      } else {
        // Simple key-value for primitive types
        sink.writeln('    $key: $value');
      }
    });
  }
}

/// Singleton logger factory to provide consistent loggers throughout the application
class LoggerFactory {
  static final Map<String, Logger> _loggers = {};
  static String? _logFilePath;
  static bool _enableRotation = false;
  static int _maxLogSizeBytes = 10 * 1024 * 1024; // 10MB default
  static int _maxBackupCount = 5;
  static int _checkIntervalSeconds = 600; // 10 minutes default

  /// Close all loggers
  static void closeAll() {
    for (final logger in _loggers.values) {
      logger.close();
    }
    _loggers.clear();
  }

  /// Configure the global logger settings
  static void configure({
    LogLevel minimumLevel = LogLevel.info,
    String? logFilePath,
    bool useJsonFormat = false,
    bool enableRotation = false,
    int maxLogSizeBytes = 10 * 1024 * 1024, // 10MB
    int maxBackupCount = 5,
    int checkIntervalSeconds = 600, // 10 minutes
  }) {
    Logger.minimumLevel = minimumLevel;
    Logger.useJsonFormatInFile = useJsonFormat;
    _logFilePath = logFilePath;
    _enableRotation = enableRotation;
    _maxLogSizeBytes = maxLogSizeBytes;
    _maxBackupCount = maxBackupCount;
    _checkIntervalSeconds = checkIntervalSeconds;
  }

  /// Get or create a logger for the specified module
  static Logger getLogger(String module) {
    if (!_loggers.containsKey(module)) {
      _loggers[module] = Logger(
        module,
        logFilePath: _logFilePath,
        enableRotation: _enableRotation,
        maxLogSizeBytes: _maxLogSizeBytes,
        maxBackupCount: _maxBackupCount,
        checkIntervalSeconds: _checkIntervalSeconds,
      );
    }
    return _loggers[module]!;
  }
}

enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical,
}

/// Handles log file rotation based on file size
class LogRotator {
  final String logFilePath;
  final int maxSizeBytes;
  final int maxBackupCount;
  final int checkIntervalSeconds;

  Timer? _timer;
  bool _rotating = false;

  LogRotator({
    required this.logFilePath,
    required this.maxSizeBytes,
    required this.maxBackupCount,
    required this.checkIntervalSeconds,
  });

  /// Start the rotation timer
  void start(Logger logger) {
    _timer = Timer.periodic(Duration(seconds: checkIntervalSeconds),
        (_) => _checkAndRotate(logger));

    // Initial check in case the file is already too large
    _checkAndRotate(logger);
  }

  /// Stop the rotation timer
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Check if rotation is needed and perform it if necessary
  void _checkAndRotate(Logger logger) {
    // Avoid concurrent rotations
    if (_rotating) return;

    final file = File(logFilePath);
    if (!file.existsSync()) return;

    // Check current file size
    final size = file.lengthSync();
    if (size >= maxSizeBytes) {
      _rotating = true;
      try {
        _rotateLogFile(logger);
      } finally {
        _rotating = false;
      }
    }
  }

  /// Delete old backup files if we exceed maxBackupCount
  void _cleanupOldBackups() {
    try {
      final dir = Directory(File(logFilePath).parent.path);
      final baseFileName = File(logFilePath)
          .uri
          .pathSegments
          .last
          .replaceFirst(RegExp(r'\.log$'), '');

      // Find all backup files for this log
      final backupPattern = RegExp('$baseFileName-\\d{8}-\\d{6}\\.log');
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
          backupFiles[i].deleteSync();
        }
      }
    } catch (e) {
      print('Failed to clean up old log backups: $e');
    }
  }

  /// Zero-pad a number to width 2
  String _pad(int n) {
    return n.toString().padLeft(2, '0');
  }

  /// Perform log file rotation
  void _rotateLogFile(Logger logger) {
    try {
      final now = DateTime.now();
      final timestamp =
          '${now.year}${_pad(now.month)}${_pad(now.day)}-${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';

      final file = File(logFilePath);
      final backupFileName =
          logFilePath.replaceFirst(RegExp(r'\.log$'), '-$timestamp.log');

      // Copy current log to backup file
      file.copySync(backupFileName);

      // Clear the current log file
      file.writeAsStringSync('');

      // Reopen the log file in the logger
      logger._reopenLogFile();

      // Delete old backup files if we have too many
      _cleanupOldBackups();
    } catch (e) {
      // If rotation fails, just print an error - don't crash the app
      print('Failed to rotate log file: $e');
    }
  }
}

