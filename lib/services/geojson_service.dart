import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/region_data.dart';

class GeoJsonService {
  static final GeoJsonService _instance = GeoJsonService._internal();
  factory GeoJsonService() => _instance;
  GeoJsonService._internal();

  // Cache for parsed GeoJSON data
  Map<String, dynamic>? _polandGeoJson;
  Map<String, dynamic>? _regionsGeoJson;
  List<LatLng>? _cachedPolygonPoints;
  List<RegionData>? _cachedRegions;
  LatLngBounds? _cachedBounds;

  Future<List<LatLng>> extractPolygonPoints() async {
    if (_cachedPolygonPoints != null) {
      debugPrint('Returning cached Poland border polygon');
      return _cachedPolygonPoints!;
    }

    try {
      if (_polandGeoJson == null) {
        debugPrint('Loading poland.geo.json...');
        final String jsonString = await rootBundle.loadString('assets/geojson/poland.geo.json');
        debugPrint('Parsing poland.geo.json...');
        _polandGeoJson = json.decode(jsonString);
      }
      
      _validateGeoJson(_polandGeoJson!, 'poland.geo.json');
      
      final features = _polandGeoJson!['features'] as List<dynamic>;
      final feature = features.first as Map<String, dynamic>;
      final geometry = feature['geometry'] as Map<String, dynamic>;
      
      if (geometry['type'] != 'Polygon') {
        throw Exception('Invalid geometry type: ${geometry['type']}');
      }
      
      final coordinates = geometry['coordinates'] as List<dynamic>;
      final outerRing = coordinates.first as List<dynamic>;
      
      debugPrint('Successfully extracted Poland border polygon');
      _cachedPolygonPoints = outerRing.map<LatLng>((coord) {
        final point = coord as List<dynamic>;
        return LatLng(point[1] as double, point[0] as double);
      }).toList();

      return _cachedPolygonPoints!;
    } catch (e, stackTrace) {
      debugPrint('Error in extractPolygonPoints: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  void _validateGeoJson(Map<String, dynamic> geoJson, String fileName) {
    if (geoJson['type'] != 'FeatureCollection') {
      throw Exception('Invalid GeoJSON type in $fileName: ${geoJson['type']}');
    }

    final features = geoJson['features'] as List<dynamic>?;
    if (features == null || features.isEmpty) {
      throw Exception('No features found in $fileName');
    }
  }

  LatLngBounds calculateBounds(List<LatLng> points) {
    if (_cachedBounds != null) {
      return _cachedBounds!;
    }

    if (points.isEmpty) {
      throw Exception('Cannot calculate bounds: empty points list');
    }

    var minLat = double.infinity;
    var maxLat = double.negativeInfinity;
    var minLng = double.infinity;
    var maxLng = double.negativeInfinity;

    // More efficient loop without comparisons
    for (var point in points) {
      minLat = minLat > point.latitude ? point.latitude : minLat;
      maxLat = maxLat < point.latitude ? point.latitude : maxLat;
      minLng = minLng > point.longitude ? point.longitude : minLng;
      maxLng = maxLng < point.longitude ? point.longitude : maxLng;
    }

    _cachedBounds = LatLngBounds(
      LatLng(maxLat, maxLng), // northEast
      LatLng(minLat, minLng), // southWest
    );

    debugPrint('Calculated bounds: NE(${maxLat.toStringAsFixed(6)}, ${maxLng.toStringAsFixed(6)}), '
               'SW(${minLat.toStringAsFixed(6)}, ${minLng.toStringAsFixed(6)})');

    return _cachedBounds!;
  }

  Future<List<RegionData>> extractRegions() async {
    if (_cachedRegions != null) {
      debugPrint('Returning cached regions data');
      return _cachedRegions!;
    }

    try {
      if (_regionsGeoJson == null) {
        debugPrint('Loading ulozone_rejony_with_random_ids.geojson...');
        final String jsonString = await rootBundle.loadString('assets/geojson/ulozone_rejony_with_random_ids.geojson');
        
        debugPrint('Parsing ulozone_rejony_with_random_ids.geojson...');
        _regionsGeoJson = json.decode(jsonString);
      }
      
      _validateGeoJson(_regionsGeoJson!, 'ulozone_rejony_with_random_ids.geojson');
      
      final features = _regionsGeoJson!['features'] as List<dynamic>;
      final List<RegionData> extractedRegions = [];
      
      int regionCount = 0;
      for (var feature in features) {
        try {
          final properties = feature['properties'] as Map<String, dynamic>;
          final geometry = feature['geometry'] as Map<String, dynamic>;
          
          final String regionId = properties['regionId'] ?? 
                                properties['random_id'] ?? 
                                'unknown_${regionCount++}';
          
          if (geometry['type'] == 'Polygon') {
            final coordinates = geometry['coordinates'] as List<dynamic>;
            final outerRing = coordinates.first as List<dynamic>;
            
            // Pre-allocate the points list
            final points = List<LatLng>.filled(outerRing.length, LatLng(0, 0));
            
            // Fill points in a single pass
            for (var i = 0; i < outerRing.length; i++) {
              final point = outerRing[i] as List<dynamic>;
              points[i] = LatLng(point[1] as double, point[0] as double);
            }
            
            final center = _calculateCenterOptimized(points);
            
            extractedRegions.add(RegionData(
              regionId: regionId,
              points: points,
              center: center,
            ));
          }
        } catch (e) {
          debugPrint('Error processing region #$regionCount: $e');
          // Continue processing other regions
          continue;
        }
      }
      
      if (extractedRegions.isEmpty) {
        throw Exception('No valid regions found in the GeoJSON data');
      }
      
      debugPrint('Successfully extracted ${extractedRegions.length} regions');
      _cachedRegions = extractedRegions;
      return extractedRegions;
    } catch (e, stackTrace) {
      debugPrint('Error in extractRegions: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  LatLng _calculateCenterOptimized(List<LatLng> points) {
    if (points.isEmpty) return LatLng(0, 0);
    
    // Use more efficient sum calculation
    var latSum = 0.0;
    var lngSum = 0.0;
    final len = points.length;
    
    for (var i = 0; i < len; i++) {
      latSum += points[i].latitude;
      lngSum += points[i].longitude;
    }
    
    return LatLng(
      latSum / len,
      lngSum / len,
    );
  }

  void clearCache() {
    _polandGeoJson = null;
    _regionsGeoJson = null;
    _cachedPolygonPoints = null;
    _cachedRegions = null;
    _cachedBounds = null;
    debugPrint('GeoJSON cache cleared');
  }
}
