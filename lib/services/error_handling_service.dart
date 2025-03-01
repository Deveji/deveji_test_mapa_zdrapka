import 'package:flutter/material.dart';
import 'logging_service.dart';

enum ErrorSeverity {
  low,    // Non-critical errors that don't affect core functionality
  medium, // Errors that affect some features but app can continue
  high    // Critical errors that require immediate attention
}

class MapError {
  final String message;
  final ErrorSeverity severity;
  final Object? error;
  final StackTrace? stackTrace;
  final DateTime timestamp;

  MapError({
    required this.message,
    required this.severity,
    this.error,
    this.stackTrace,
  }) : timestamp = DateTime.now();

  @override
  String toString() => 'MapError: $message (Severity: ${severity.name})';
}

class ErrorHandlingService {
  static final ErrorHandlingService _instance = ErrorHandlingService._internal();
  factory ErrorHandlingService() => _instance;
  
  final LoggingService _logger = LoggingService();
  final List<MapError> _errorHistory = [];
  final _maxHistorySize = 50;

  // Error handling callbacks
  VoidCallback? onHighSeverityError;
  ValueChanged<MapError>? onErrorOccurred;

  ErrorHandlingService._internal();

  void handleError(String message, {
    ErrorSeverity severity = ErrorSeverity.medium,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final mapError = MapError(
      message: message,
      severity: severity,
      error: error,
      stackTrace: stackTrace,
    );

    // Log the error
    _logger.error(
      message,
      error: error,
      stackTrace: stackTrace,
    );

    // Add to history
    _addToHistory(mapError);

    // Notify listeners
    onErrorOccurred?.call(mapError);

    // Handle based on severity
    switch (severity) {
      case ErrorSeverity.low:
        _handleLowSeverityError(mapError);
      case ErrorSeverity.medium:
        _handleMediumSeverityError(mapError);
      case ErrorSeverity.high:
        _handleHighSeverityError(mapError);
    }
  }

  void _handleLowSeverityError(MapError error) {
    // Log and continue
    _logger.warning('Low severity error: ${error.message}');
  }

  void _handleMediumSeverityError(MapError error) {
    // Log and attempt recovery
    _logger.error('Medium severity error: ${error.message}');
    // Could implement automatic retry logic here
  }

  void _handleHighSeverityError(MapError error) {
    // Log and notify
    _logger.error(
      'High severity error: ${error.message}',
      error: error.error,
      stackTrace: error.stackTrace,
    );
    
    onHighSeverityError?.call();
  }

  void _addToHistory(MapError error) {
    _errorHistory.add(error);
    if (_errorHistory.length > _maxHistorySize) {
      _errorHistory.removeAt(0);
    }
  }

  List<MapError> getErrorHistory() {
    return List.unmodifiable(_errorHistory);
  }

  void clearErrorHistory() {
    _errorHistory.clear();
  }

  // Error recovery strategies
  Future<bool> attemptRecovery(MapError error) async {
    _logger.info('Attempting recovery for error: ${error.message}');
    
    switch (error.severity) {
      case ErrorSeverity.low:
        return true; // Low severity errors don't need recovery
      case ErrorSeverity.medium:
        return _attemptMediumSeverityRecovery(error);
      case ErrorSeverity.high:
        return _attemptHighSeverityRecovery(error);
    }
  }

  Future<bool> _attemptMediumSeverityRecovery(MapError error) async {
    _logger.info('Attempting medium severity recovery');
    
    try {
      // Implement recovery strategy
      // For example: retry failed operations, clear caches, etc.
      return true;
    } catch (e, stackTrace) {
      _logger.error(
        'Recovery failed',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> _attemptHighSeverityRecovery(MapError error) async {
    _logger.info('Attempting high severity recovery');
    
    try {
      // Implement more aggressive recovery strategy
      // For example: reset state, clear all caches, restart services
      return true;
    } catch (e, stackTrace) {
      _logger.error(
        'High severity recovery failed',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // Helper methods for common error scenarios
  void handleDataLoadError(String operation, Object error, StackTrace stackTrace) {
    handleError(
      'Error loading data during $operation',
      severity: ErrorSeverity.medium,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void handleNetworkError(String operation, Object error, StackTrace stackTrace) {
    handleError(
      'Network error during $operation',
      severity: ErrorSeverity.medium,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void handleStateError(String operation, Object error, StackTrace stackTrace) {
    handleError(
      'State error during $operation',
      severity: ErrorSeverity.high,
      error: error,
      stackTrace: stackTrace,
    );
  }
}