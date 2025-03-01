import 'error_handling_service.dart';
import 'geojson_service.dart';
import 'image_cache_service.dart';
import 'logging_service.dart';
import 'map_state_service.dart';

/// A service locator pattern implementation for managing all application services.
/// This provides a centralized way to access services and manage their lifecycles.
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  late final LoggingService _loggingService;
  late final ErrorHandlingService _errorHandlingService;
  late final MapStateService _mapStateService;
  late final ImageCacheService _imageCacheService;
  late final GeoJsonService _geoJsonService;
  bool _isInitialized = false;

  /// Initialize all services in the correct order
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize core services first
      _loggingService = LoggingService();
      _loggingService.info('Initializing services...');

      _errorHandlingService = ErrorHandlingService();
      
      // Initialize feature services
      _mapStateService = MapStateService();
      _imageCacheService = ImageCacheService();
      _geoJsonService = GeoJsonService();

      _isInitialized = true;
      _loggingService.info('All services initialized successfully');
    } catch (e, stackTrace) {
      _loggingService.error(
        'Failed to initialize services',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Clean up and dispose of services
  Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      _loggingService.info('Disposing services...');
      
      // Dispose in reverse order of initialization
      _geoJsonService.clearCache();
      _imageCacheService.clearCache();
      _mapStateService.reset();

      _isInitialized = false;
      _loggingService.info('All services disposed successfully');
    } catch (e, stackTrace) {
      _loggingService.error(
        'Error disposing services',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // Service getters
  LoggingService get logging {
    _checkInitialization();
    return _loggingService;
  }

  ErrorHandlingService get errorHandling {
    _checkInitialization();
    return _errorHandlingService;
  }

  MapStateService get mapState {
    _checkInitialization();
    return _mapStateService;
  }

  ImageCacheService get imageCache {
    _checkInitialization();
    return _imageCacheService;
  }

  GeoJsonService get geoJson {
    _checkInitialization();
    return _geoJsonService;
  }

  void _checkInitialization() {
    if (!_isInitialized) {
      throw StateError('ServiceLocator not initialized. Call initialize() first.');
    }
  }

  // Convenience methods for error handling
  void handleError(String message, {
    ErrorSeverity severity = ErrorSeverity.medium,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _checkInitialization();
    _errorHandlingService.handleError(
      message,
      severity: severity,
      error: error,
      stackTrace: stackTrace,
    );
  }

  // Helper method to check service health
  Map<String, bool> checkServicesHealth() {
    return {
      'logging': _isInitialized,
      'errorHandling': _isInitialized,
      'mapState': _isInitialized && _mapStateService.regions.isNotEmpty,
      'imageCache': _isInitialized && _imageCacheService.isImageCached('assets/images/poland.jpg'),
      'geoJson': _isInitialized,
    };
  }
}