import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../models/region_data.dart';

class RegionsLayer extends StatelessWidget {
  final List<RegionData> regions;
  
  const RegionsLayer({
    super.key,
    required this.regions,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: PolygonLayer(
        polygons: regions.map((region) => Polygon(
          points: region.points,
          color: region.isSelected 
              ? Colors.transparent
              : Colors.grey,
          borderColor: region.isSelected 
              ? Colors.transparent
              : Colors.brown.withOpacity(0.7),
          borderStrokeWidth: 3,
          isFilled: true,
        )).toList(),
      ),
    );
  }
}
