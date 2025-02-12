import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error;

  String get name => toString().split('.').last.toUpperCase();
}

class Logger {
  static LogLevel _minimumLevel = kDebugMode ? LogLevel.debug : LogLevel.info;
  static bool _includeTimestamp = true;
  static final Map<LogLevel, String> _colorCodes = {
    LogLevel.debug: '\x1B[37m',
    LogLevel.info: '\x1B[34m',
    LogLevel.warning: '\x1B[33m',
    LogLevel.error: '\x1B[31m',
  };
  static const String _resetCode = '\x1B[0m';

  static void configure({
    LogLevel? minimumLevel,
    bool? includeTimestamp,
  }) {
    if (minimumLevel != null) _minimumLevel = minimumLevel;
    if (includeTimestamp != null) _includeTimestamp = includeTimestamp;
  }

  static String _formatMessage(LogLevel level, String message) {
    final timestamp =
        _includeTimestamp ? '[${DateTime.now().toIso8601String()} ' : '';
    final levelStr = '[${level.name}] ';

    if (kDebugMode) {
      return '${_colorCodes[level]}$timestamp$levelStr$message$_resetCode';
    }

    return '$timestamp$levelStr$message';
  }

  static void _log(LogLevel level, String message,
      [Object? error, StackTrace? stackTrace]) {
    if (level.index < _minimumLevel.index) return;

    final formattedMessage = _formatMessage(level, message);

    if (level == LogLevel.error) {
      FlutterError.presentError(FlutterErrorDetails(
        exception: error ?? message,
        stack: stackTrace,
        library: 'Logger',
      ));
    }

    developer.log(
      formattedMessage,
      time: DateTime.now(),
      level: level.index * 100,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void debug(String message) => _log(LogLevel.debug, message);

  static void info(String message) => _log(LogLevel.info, message);

  static void warning(String message, [Object? error]) =>
      _log(LogLevel.warning, message, error);

  static void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _log(LogLevel.error, message, error, stackTrace);

  static void apiError(String endpoint, Object error, StackTrace? stackTrace) {
    _log(
      LogLevel.error,
      'API error on $endpoint',
      error,
      stackTrace,
    );
  }

  static void authEvent(String event) {
    _log(
      LogLevel.info,
      'Auth: $event',
    );
  }
}
