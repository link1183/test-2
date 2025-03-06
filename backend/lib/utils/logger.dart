import 'dart:convert';
import 'dart:io';

/// A structured logging utility that supports multiple output destinations
/// and different log levels.
class Logger {
  /// The minimum log level that will be processed
  static LogLevel minimumLevel = LogLevel.info;
  final String module;
  final bool enableConsole;

  final IOSink? _logFile;

  /// Create a new logger for the specified module
  ///
  /// Parameters:
  /// - module: The name of the module this logger is for
  /// - enableConsole: Whether to print logs to the console
  /// - logFilePath: Optional path to a file to write logs to
  factory Logger(String module,
      {bool enableConsole = true, String? logFilePath}) {
    IOSink? logFile;
    if (logFilePath != null) {
      final file = File(logFilePath);
      logFile = file.openWrite(mode: FileMode.append);
    }

    return Logger._internal(module, enableConsole, logFile);
  }

  Logger._internal(this.module, this.enableConsole, this._logFile);

  /// Close the logger and any associated resources
  void close() {
    _logFile?.close();
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

  /// Internal method to process and output logs
  void _log(LogLevel level, String message, [Map<String, dynamic>? data]) {
    if (level.index < minimumLevel.index) return;

    final timestamp = DateTime.now().toIso8601String();
    final logEntry = {
      'timestamp': timestamp,
      'level': level.toString().split('.').last,
      'module': module,
      'message': message,
      if (data != null) 'data': data,
    };

    final logString = json.encode(logEntry);

    if (enableConsole) {
      // Different colors for different log levels
      String colorCode;
      switch (level) {
        case LogLevel.debug:
          colorCode = '\x1B[37m'; // Gray
          break;
        case LogLevel.info:
          colorCode = '\x1B[32m'; // Green
          break;
        case LogLevel.warning:
          colorCode = '\x1B[33m'; // Yellow
          break;
        case LogLevel.error:
          colorCode = '\x1B[31m'; // Red
          break;
        case LogLevel.critical:
          colorCode = '\x1B[35m'; // Purple
          break;
      }

      print('$colorCode$logString\x1B[0m');
    }

    _logFile?.writeln(logString);
  }
}

/// Singleton logger factory to provide consistent loggers throughout the application
class LoggerFactory {
  static final Map<String, Logger> _loggers = {};
  static String? _logFilePath;

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
  }) {
    Logger.minimumLevel = minimumLevel;
    _logFilePath = logFilePath;
  }

  /// Get or create a logger for the specified module
  static Logger getLogger(String module) {
    if (!_loggers.containsKey(module)) {
      _loggers[module] = Logger(module, logFilePath: _logFilePath);
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
