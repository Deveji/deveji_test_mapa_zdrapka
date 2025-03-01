import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/region_data.dart';
import 'logging_service.dart';

class MapStateService extends ChangeNotifier {
  static final MapStateService _instance = MapStateService._internal();
  factory MapStateService() => _instance;
  final _logger = LoggingService();

  MapStateService._internal() {
    _logger.info('MapStateService initialized');
  }

  // View state
  double _currentZoom = 7.0;
  LatLng _center = LatLng(52.0, 19.0); // Default center of Poland
  bool _isLoading = false;
  String? _error;

  // Data state
  List<RegionData> _regions = [];
  List<LatLng> _borderPoints = [];
  LatLngBounds? _mapBounds;

  // Interactive state
  String? _hoveredRegionId;
  String? _selectedRegionId;
  bool _isHighQualityImageLoaded = false;

  // Getters
  double get currentZoom => _currentZoom;
  LatLng get center => _center;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<RegionData> get regions => List.unmodifiable(_regions);
  List<LatLng> get borderPoints => List.unmodifiable(_borderPoints);
  LatLngBounds? get mapBounds => _mapBounds;
  String? get hoveredRegionId => _hoveredRegionId;
  String? get selectedRegionId => _selectedRegionId;
  bool get isHighQualityImageLoaded => _isHighQualityImageLoaded;

  // Computed properties
  RegionData? get selectedRegion => _selectedRegionId != null 
    ? _regions.firstWhere(
        (r) => r.regionId == _selectedRegionId,
        orElse: () => null as RegionData,
      )
    : null;

  RegionData? get hoveredRegion => _hoveredRegionId != null
    ? _regions.firstWhere(
        (r) => r.regionId == _hoveredRegionId,
        orElse: () => null as RegionData,
      )
    : null;

  // State updates
  void updateZoom(double zoom) {
    if (_currentZoom != zoom) {
      _currentZoom = zoom;
      _logger.debug('Zoom updated to: $zoom');
      notifyListeners();
    }
  }

  void updateCenter(LatLng center) {
    if (_center != center) {
      _center = center;
      _logger.debug('Center updated to: ${center.latitude}, ${center.longitude}');
      notifyListeners();
    }
  }

  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      _logger.debug('Loading state: $loading');
      notifyListeners();
    }
  }

  void setError(String? error) {
    _error = error;
    if (error != null) {
      _logger.error('Map error: $error');
    }
    notifyListeners();
  }

  void setBorderPoints(List<LatLng> points) {
    _borderPoints = List.from(points);
    _logger.info('Border points updated: ${points.length} points');
    notifyListeners();
  }

  void setMapBounds(LatLngBounds bounds) {
    _mapBounds = bounds;
    _logger.debug('Map bounds updated');
    notifyListeners();
  }

  void setRegions(List<RegionData> regions) {
    _regions = List.from(regions);
    _logger.info('Regions updated: ${regions.length} regions');
    notifyListeners();
  }

  void setHoveredRegion(String? regionId) {
    if (_hoveredRegionId != regionId) {
      _hoveredRegionId = regionId;
      _logger.debug('Hover region: $regionId');
      notifyListeners();
    }
  }

  void setSelectedRegion(String? regionId) {
    if (_selectedRegionId != regionId) {
      _selectedRegionId = regionId;
      _logger.info('Selected region: $regionId');
      notifyListeners();
    }
  }

  void setHighQualityImageLoaded(bool loaded) {
    if (_isHighQualityImageLoaded != loaded) {
      _isHighQualityImageLoaded = loaded;
      _logger.info('High quality image loaded: $loaded');
      notifyListeners();
    }
  }

  // Batch updates
  void updateMapState({
    double? zoom,
    LatLng? center,
    bool? loading,
    String? error,
    List<LatLng>? borderPoints,
    LatLngBounds? bounds,
    List<RegionData>? regions,
    String? hoveredRegionId,
    String? selectedRegionId,
    bool? highQualityImageLoaded,
  }) {
    bool shouldNotify = false;

    if (zoom != null && _currentZoom != zoom) {
      _currentZoom = zoom;
      shouldNotify = true;
    }
    if (center != null && _center != center) {
      _center = center;
      shouldNotify = true;
    }
    if (loading != null && _isLoading != loading) {
      _isLoading = loading;
      shouldNotify = true;
    }
    if (error != null && _error != error) {
      _error = error;
      shouldNotify = true;
    }
    if (borderPoints != null) {
      _borderPoints = List.from(borderPoints);
      shouldNotify = true;
    }
    if (bounds != null && _mapBounds != bounds) {
      _mapBounds = bounds;
      shouldNotify = true;
    }
    if (regions != null) {
      _regions = List.from(regions);
      shouldNotify = true;
    }
    if (hoveredRegionId != null && _hoveredRegionId != hoveredRegionId) {
      _hoveredRegionId = hoveredRegionId;
      shouldNotify = true;
    }
    if (selectedRegionId != null && _selectedRegionId != selectedRegionId) {
      _selectedRegionId = selectedRegionId;
      shouldNotify = true;
    }
    if (highQualityImageLoaded != null && _isHighQualityImageLoaded != highQualityImageLoaded) {
      _isHighQualityImageLoaded = highQualityImageLoaded;
      shouldNotify = true;
    }

    if (shouldNotify) {
      _logger.debug('Batch map state update');
      notifyListeners();
    }
  }

  // Reset state
  void reset() {
    _currentZoom = 7.0;
    _center = LatLng(52.0, 19.0);
    _isLoading = false;
    _error = null;
    _regions = [];
    _borderPoints = [];
    _mapBounds = null;
    _hoveredRegionId = null;
    _selectedRegionId = null;
    _isHighQualityImageLoaded = false;
    
    _logger.info('Map state reset');
    notifyListeners();
  }
}