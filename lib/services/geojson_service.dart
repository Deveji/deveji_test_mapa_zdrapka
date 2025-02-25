import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

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

}
