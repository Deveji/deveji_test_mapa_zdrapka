import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class BorderLayer extends StatelessWidget {
  final List<LatLng> borderPoints;
  final Color borderColor;
  final double borderWidth;
  
  const BorderLayer({
    super.key,
    required this.borderPoints,
    this.borderColor = const Color.fromRGBO(77, 63, 50, 1.0),
    this.borderWidth = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: PolygonLayer(
        polygons: [
          Polygon(
            points: borderPoints,
            color: Colors.transparent,
            borderStrokeWidth: borderWidth,
            borderColor: borderColor,
          ),
        ],
      ),
    );
  }
}
