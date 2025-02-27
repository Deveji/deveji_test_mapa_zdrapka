import 'package:latlong2/latlong.dart';
import '../../../models/region_data.dart';

class PointInPolygonUtil {
  // Find which region contains the given point
  static RegionData? findRegionAt(LatLng point, List<RegionData> regions) {
    // First, filter regions by bounding box (fast check)
    final candidateRegions = regions.where((region) => 
      region.containsPointInBoundingBox(point)
    ).toList();
    
    // Then do detailed point-in-polygon check only for candidates
    for (var region in candidateRegions) {
      if (isPointInPolygon(point, region.points)) {
        return region;
      }
    }
    
    return null;
  }
  
  // Check if a point is inside a polygon using ray-casting algorithm
  static bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    bool isInside = false;
    int i = 0, j = polygon.length - 1;
    
    for (i = 0; i < polygon.length; i++) {
      if ((polygon[i].latitude > point.latitude) != (polygon[j].latitude > point.latitude) &&
          (point.longitude < (polygon[j].longitude - polygon[i].longitude) * 
          (point.latitude - polygon[i].latitude) / 
          (polygon[j].latitude - polygon[i].latitude) + polygon[i].longitude)) {
        isInside = !isInside;
      }
      j = i;
    }
    
    return isInside;
  }
}
