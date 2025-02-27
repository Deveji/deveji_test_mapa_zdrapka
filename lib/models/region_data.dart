import 'package:latlong2/latlong.dart';

class RegionData {
  final String regionId;
  final List<LatLng> points;
  final LatLng center;
  bool isSelected;

  RegionData({
    required this.regionId,
    required this.points,
    required this.center,
    this.isSelected = false,
  });

  // Create a copy of this RegionData with updated selection state
  RegionData copyWith({bool? isSelected}) {
    return RegionData(
      regionId: regionId,
      points: points,
      center: center,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
