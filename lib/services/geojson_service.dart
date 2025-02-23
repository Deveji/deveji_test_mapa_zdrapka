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

  Future<List<List<LatLng>>> extractCountyPolygons() async {
    try {
      debugPrint('Loading poland.counties.json...');
      final String jsonString = await rootBundle.loadString('lib/constants/poland.counties.json');
      debugPrint('Parsing poland.counties.json...');
      final Map<String, dynamic> geoJson = json.decode(jsonString);
      
      if (geoJson['type'] != 'FeatureCollection') {
        throw Exception('Invalid GeoJSON type: ${geoJson['type']}');
      }
      
      final features = geoJson['features'] as List<dynamic>;
      final validPolygons = <List<LatLng>>[];

      for (var i = 0; i < features.length; i++) {
        try {
          final feature = features[i] as Map<String, dynamic>;
          final geometry = feature['geometry'] as Map<String, dynamic>;
          
          if (geometry['type'] == 'Polygon') {
            final coordinates = geometry['coordinates'] as List<dynamic>;
            final outerRing = coordinates.first as List<dynamic>;
            validPolygons.add(_convertCoordinatesToLatLng(outerRing));
          } else if (geometry['type'] == 'MultiPolygon') {
            final polygons = geometry['coordinates'] as List<dynamic>;
            for (var polygon in polygons) {
              final outerRing = (polygon as List<dynamic>).first as List<dynamic>;
              validPolygons.add(_convertCoordinatesToLatLng(outerRing));
            }
          } else {
            debugPrint('Unknown geometry type at index $i: ${geometry['type']}');
          }
        } catch (e) {
          debugPrint('Error processing county at index $i: $e');
          // Continue processing other counties
        }
      }

      debugPrint('Successfully extracted ${validPolygons.length} county polygons');
      return validPolygons;
    } catch (e, stackTrace) {
      debugPrint('Error in extractCountyPolygons: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  List<LatLng> _convertCoordinatesToLatLng(List<dynamic> coordinates) {
    return coordinates.map<LatLng>((coord) {
      final point = coord as List<dynamic>;
      return LatLng(point[1] as double, point[0] as double);
    }).toList();
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

  LatLng calculateCenter(List<LatLng> points) {
    if (points.isEmpty) {
      throw Exception('Cannot calculate center: empty points list');
    }

    double sumLat = 0;
    double sumLng = 0;
    
    for (var point in points) {
      sumLat += point.latitude;
      sumLng += point.longitude;
    }

    final center = LatLng(
      sumLat / points.length,
      sumLng / points.length,
    );

    debugPrint('Calculated center: (${center.latitude.toStringAsFixed(6)}, ${center.longitude.toStringAsFixed(6)})');
    return center;
  }
}
