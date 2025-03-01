import 'package:flutter/foundation.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error
}

class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  final bool _isDebugMode = kDebugMode;
  final List<String> _logHistory = [];
  final int _maxHistorySize = 1000;

  void log(String message, {LogLevel level = LogLevel.info, Object? error, StackTrace? stackTrace}) {
    final timestamp = DateTime.now();
    final formattedMessage = _formatLogMessage(timestamp, level, message, error, stackTrace);
    
    _addToHistory(formattedMessage);

    if (_isDebugMode) {
      switch (level) {
        case LogLevel.debug:
          debugPrint('🔍 $formattedMessage');
        case LogLevel.info:
          debugPrint('ℹ️ $formattedMessage');
        case LogLevel.warning:
          debugPrint('⚠️ $formattedMessage');
        case LogLevel.error:
          debugPrint('❌ $formattedMessage');
          if (error != null) {
            debugPrint('Error details: $error');
          }
          if (stackTrace != null) {
            debugPrint('Stack trace:\n$stackTrace');
          }
      }
    }
  }

  String _formatLogMessage(DateTime timestamp, LogLevel level, String message, Object? error, StackTrace? stackTrace) {
    final buffer = StringBuffer()
      ..write('[${timestamp.toIso8601String()}] ')
      ..write('${level.name.toUpperCase()}: ')
      ..write(message);

    if (error != null) {
      buffer.write(' | Error: $error');
    }

    return buffer.toString();
  }

  void _addToHistory(String logMessage) {
    _logHistory.add(logMessage);
    if (_logHistory.length > _maxHistorySize) {
      _logHistory.removeAt(0);
    }
  }

  List<String> getLogHistory() {
    return List.unmodifiable(_logHistory);
  }

  void clearHistory() {
    _logHistory.clear();
  }

  void debug(String message) => log(message, level: LogLevel.debug);
  void info(String message) => log(message, level: LogLevel.info);
  void warning(String message) => log(message, level: LogLevel.warning);
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    log(message, level: LogLevel.error, error: error, stackTrace: stackTrace);
  }
}