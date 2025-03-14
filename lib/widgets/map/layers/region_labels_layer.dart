import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../../models/region_data.dart';

/// A cached text style configuration to prevent recreating styles
class _LabelStyle {
  final TextStyle style;
  final Size size;

  const _LabelStyle(this.style, this.size);
}

class RegionLabelsLayer extends StatefulWidget {
  final List<RegionData> regions;
  final double zoomLevel;
  
  const RegionLabelsLayer({
    super.key,
    required this.regions,
    required this.zoomLevel,
  });

  @override
  State<RegionLabelsLayer> createState() => _RegionLabelsLayerState();
}

class _RegionLabelsLayerState extends State<RegionLabelsLayer> {
  // Cache for text styles and measurements
  final Map<String, _LabelStyle> _styleCache = {};
  
  // Store previous zoom level to detect significant changes
  double? _previousZoom;
  
  // Cached markers
  List<Marker>? _cachedMarkers;
  
  @override
  void dispose() {
    _clearCache();
    super.dispose();
  }

  void _clearCache() {
    _styleCache.clear();
    _cachedMarkers = null;
  }

  bool _shouldUpdateMarkers(double newZoom) {
    if (_previousZoom == null) return true;
    
    // Update if zoom changed by more than 0.1 or cache is empty
    final shouldUpdate = (_cachedMarkers == null) ||
        (newZoom - _previousZoom!).abs() > 0.1;
    
    if (shouldUpdate) {
      _previousZoom = newZoom;
    }
    
    return shouldUpdate;
  }

  _LabelStyle _getStyleForRegion(RegionData region, double fontSize) {
    final key = '${region.regionId}_${region.isSelected}_$fontSize';
    
    if (_styleCache.containsKey(key)) {
      return _styleCache[key]!;
    }

    final style = TextStyle(
      color: region.isSelected ? Colors.blue.shade900 : Colors.black,
      fontWeight: region.isSelected ? FontWeight.bold : FontWeight.normal,
      fontSize: fontSize,
    );

    // Measure text size for collision detection
    final textPainter = TextPainter(
      text: TextSpan(text: region.regionId, style: style),
      // maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    final labelStyle = _LabelStyle(style, Size(textPainter.width, textPainter.height));
    _styleCache[key] = labelStyle;
    
    return labelStyle;
  }

  List<Marker> _createMarkers() {
    final effectiveZoomLevel = widget.zoomLevel > 0 ? widget.zoomLevel : 7.0;
    
    // Optimize zoom-based font size calculation
    final zoomFactor = (effectiveZoomLevel / 7.0);
    final fontSize = 2 * (zoomFactor * zoomFactor * zoomFactor * 3.0);

    // Sort regions by priority (selected first, then by size)
    final sortedRegions = List<RegionData>.from(widget.regions)
      ..sort((a, b) {
        if (a.isSelected != b.isSelected) {
          return b.isSelected ? 1 : -1;
        }
        return 0;
      });

    final markers = <Marker>[];
    final usedAreas = <Rect>[];

    for (final region in sortedRegions) {
      final labelStyle = _getStyleForRegion(region, fontSize);
      final labelSize = labelStyle.size;
      
      // Calculate label rectangle for collision detection
      final labelRect = Rect.fromCenter(
        center: Offset(region.center.longitude, region.center.latitude),
        width: labelSize.width / 100000, // Scale for coordinate space
        height: labelSize.height / 100000,
      );

      // Check for collisions with existing labels
      bool hasCollision = usedAreas.any((area) => area.overlaps(labelRect));
      
      if (!hasCollision) {
        markers.add(
          Marker(
            point: region.center,
            width: labelSize.width + 10, // Add padding
            height: labelSize.height + 15,
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                style: labelStyle.style,
                child: Text(region.regionId.replaceAll(' ', '\n')),
              ),
            ),
          ),
        );
        usedAreas.add(labelRect);
      }
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveZoomLevel = widget.zoomLevel > 0 ? widget.zoomLevel : 7.0;
    
    // Only show text at higher zoom levels
    if (effectiveZoomLevel <= 6.5) {
      return const SizedBox.shrink();
    }

    // Update markers only when necessary
    if (_shouldUpdateMarkers(effectiveZoomLevel)) {
      _cachedMarkers = _createMarkers();
    }

    return RepaintBoundary(
      child: MarkerLayer(
        markers: _cachedMarkers ?? [],
      ),
    );
  }
}
