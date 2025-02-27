import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../models/region_data.dart';
import '../../../services/region_manager.dart';
import '../utils/map_calculation_helper.dart';

class RegionLabelsLayer extends StatelessWidget {
  final List<RegionData> regions;
  final double zoomLevel;
  
  const RegionLabelsLayer({
    super.key,
    required this.regions,
    required this.zoomLevel,
  });

  @override
  Widget build(BuildContext context) {
    // Use a default zoom level if the provided one is not valid
    final effectiveZoomLevel = zoomLevel > 0 ? zoomLevel : 7.0;
    
    // Make text very small at low zoom levels, and increase size more dramatically at higher zoom levels
    // Use a cubic scaling function for more dramatic growth at higher zoom levels
    final zoomFactor = (effectiveZoomLevel / 7.0);
    final fontSize = 2 * (zoomFactor * zoomFactor * zoomFactor * 3.0); // Cubic scaling for more dramatic effect
    
    // Only show text at higher zoom levels
    final visible = effectiveZoomLevel > 6.5;
    
    // If not visible, return an empty layer
    if (!visible) {
      return const SizedBox.shrink();
    }
    
    return RepaintBoundary(
      child: MarkerLayer(
        markers: regions.map((region) {
          final isSelected = region.isSelected;
          
          return Marker(
            point: region.center,
            width: 80,
            height: 30,
            child: Center(
              child: Text(
                region.regionId,
                style: TextStyle(
                  color: isSelected ? Colors.blue.shade900 : Colors.black,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: fontSize,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
