import 'package:latlong2/latlong.dart';

// Define a type for the hit value
typedef RegionHitValue = ({String regionId, String subtitle});

class RegionData {
  final String regionId;
  final List<LatLng> points;
  final LatLng center;
  bool isSelected;
  
  // Cached bounding box for performance
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  RegionData({
    required this.regionId,
    required this.points,
    required this.center,
    this.isSelected = false,
    double? minLat,
    double? maxLat,
    double? minLng,
    double? maxLng,
  }) : minLat = minLat ?? _calculateMinLat(points),
       maxLat = maxLat ?? _calculateMaxLat(points),
       minLng = minLng ?? _calculateMinLng(points),
       maxLng = maxLng ?? _calculateMaxLng(points);

  // Create a copy of this RegionData with updated selection state
  RegionData copyWith({bool? isSelected}) {
    return RegionData(
      regionId: regionId,
      points: points,
      center: center,
      isSelected: isSelected ?? this.isSelected,
      // Pass the existing bounding box values to avoid recalculation
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
    );
  }
  
  // Convert to hit value for PolygonLayer
  RegionHitValue toHitValue() {
    return (
      regionId: regionId,
      subtitle: 'Region ID: $regionId',
    );
  }
  
  // Static methods to calculate bounding box values
  static double _calculateMinLat(List<LatLng> points) {
    if (points.isEmpty) return 0;
    double min = points[0].latitude;
    for (var i = 1; i < points.length; i++) {
      if (points[i].latitude < min) min = points[i].latitude;
    }
    return min;
  }
  
  static double _calculateMaxLat(List<LatLng> points) {
    if (points.isEmpty) return 0;
    double max = points[0].latitude;
    for (var i = 1; i < points.length; i++) {
      if (points[i].latitude > max) max = points[i].latitude;
    }
    return max;
  }
  
  static double _calculateMinLng(List<LatLng> points) {
    if (points.isEmpty) return 0;
    double min = points[0].longitude;
    for (var i = 1; i < points.length; i++) {
      if (points[i].longitude < min) min = points[i].longitude;
    }
    return min;
  }
  
  static double _calculateMaxLng(List<LatLng> points) {
    if (points.isEmpty) return 0;
    double max = points[0].longitude;
    for (var i = 1; i < points.length; i++) {
      if (points[i].longitude > max) max = points[i].longitude;
    }
    return max;
  }
  
  // Check if a point is within this region's bounding box
  bool containsPointInBoundingBox(LatLng point) {
    return point.latitude >= minLat && 
           point.latitude <= maxLat && 
           point.longitude >= minLng && 
           point.longitude <= maxLng;
  }
}
