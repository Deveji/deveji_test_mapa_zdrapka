import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

/// The approximate center point of Poland's territory.
/// These coordinates represent the geographical center calculated from Poland's border polygon.
final polandCenter = LatLng(51.9194, 19.1451);

/// Image position adjustment variables for fine-tuning the overlay position
const imageAdjustment = ImageAdjustment(
  top: 0.3,
  bottom: 0.45,
  left: 0.08,
  right: 0.25,
);

/// Bounds for the Poland overlay image
final polandBounds = LatLngBounds(
  LatLng(54.8357, 24.1630), // northEast
  LatLng(49.0273, 14.1224), // southWest
);

/// Helper class for image position adjustment
class ImageAdjustment {
  final double top;
  final double bottom;
  final double left;
  final double right;

  const ImageAdjustment({
    required this.top,
    required this.bottom,
    required this.left,
    required this.right,
  });
}
