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

  Future<List<LatLng>> extractPolygonPoints() async {
    try {
      debugPrint('Loading poland.geo.json...');
      final String jsonString = await rootBundle.loadString('lib/constants/poland.geo.json');
      debugPrint('Parsing poland.geo.json...');
      final Map<String, dynamic> geoJson = json.decode(jsonString);
      
      if (geoJson['type'] != 'FeatureCollection') {
        throw Exception('Invalid GeoJSON type: ${geoJson['type']}');
      }
      
      final features = geoJson['features'] as List<dynamic>;
      if (features.isEmpty) {
        throw Exception('No features found in poland.geo.json');
      }
      
      final feature = features.first as Map<String, dynamic>;
      final geometry = feature['geometry'] as Map<String, dynamic>;
      
      if (geometry['type'] != 'Polygon') {
        throw Exception('Invalid geometry type: ${geometry['type']}');
      }
      
      final coordinates = geometry['coordinates'] as List<dynamic>;
      final outerRing = coordinates.first as List<dynamic>;
      
      debugPrint('Successfully extracted Poland border polygon');
      return outerRing.map<LatLng>((coord) {
        final point = coord as List<dynamic>;
        return LatLng(point[1] as double, point[0] as double);
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('Error in extractPolygonPoints: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  LatLngBounds calculateBounds(List<LatLng> points) {
    if (points.isEmpty) {
      throw Exception('Cannot calculate bounds: empty points list');
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var point in points) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }

    debugPrint('Calculated bounds: NE(${maxLat.toStringAsFixed(6)}, ${maxLng.toStringAsFixed(6)}), '
               'SW(${minLat.toStringAsFixed(6)}, ${minLng.toStringAsFixed(6)})');

    return LatLngBounds(
      LatLng(maxLat, maxLng), // northEast
      LatLng(minLat, minLng), // southWest
    );
  }

  Future<List<RegionData>> extractRegions() async {
    try {
      debugPrint('Loading ulozone_rejony_with_random_ids.geojson...');
      final String jsonString = await rootBundle.loadString('lib/constants/ulozone_rejony_with_random_ids.geojson');
      
      debugPrint('Parsing ulozone_rejony_with_random_ids.geojson...');
      final Map<String, dynamic> geoJson = json.decode(jsonString);
      
      if (geoJson['type'] != 'FeatureCollection') {
        throw Exception('Invalid GeoJSON type: ${geoJson['type']}');
      }
      
      final features = geoJson['features'] as List<dynamic>;
      if (features.isEmpty) {
        throw Exception('No features found in ulozone_rejony_with_random_ids.geojson');
      }
      
      List<RegionData> regions = [];
      
      for (var feature in features) {
        final properties = feature['properties'] as Map<String, dynamic>;
        final geometry = feature['geometry'] as Map<String, dynamic>;
        
        // Get regionId (or use a fallback if not available)
        final String regionId = properties['regionId'] ?? properties['random_id'] ?? 'unknown';
        
        if (geometry['type'] == 'Polygon') {
          final coordinates = geometry['coordinates'] as List<dynamic>;
          final outerRing = coordinates.first as List<dynamic>;
          
          final points = outerRing.map<LatLng>((coord) {
            final point = coord as List<dynamic>;
            return LatLng(point[1] as double, point[0] as double);
          }).toList();
          
          // Calculate center for text placement
          final center = calculateCenter(points);
          
          regions.add(RegionData(
            regionId: regionId,
            points: points,
            center: center,
          ));
        }
      }
      
      debugPrint('Successfully extracted ${regions.length} regions');
      return regions;
    } catch (e, stackTrace) {
      debugPrint('Error in extractRegions: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  LatLng calculateCenter(List<LatLng> points) {
    double latitude = 0;
    double longitude = 0;
    
    for (var point in points) {
      latitude += point.latitude;
      longitude += point.longitude;
    }
    
    return LatLng(
      latitude / points.length,
      longitude / points.length,
    );
  }
}
