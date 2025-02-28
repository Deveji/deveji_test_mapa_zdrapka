import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/region_data.dart';

class RegionManager extends ChangeNotifier {
  static final RegionManager _instance = RegionManager._internal();
  factory RegionManager() => _instance;
  RegionManager._internal();

  List<RegionData> _regions = [];
  String? _selectedRegionId;
  
  // For hover effects
  final ValueNotifier<String?> hoverRegionId = ValueNotifier(null);

  // For caching hover polygons
  List<Polygon>? _hoverPolygons;
  List<Polygon>? get hoverPolygons => _hoverPolygons;

  // Get all regions
  UnmodifiableListView<RegionData> get regions => UnmodifiableListView(_regions);

  // Get the currently selected region
  RegionData? get selectedRegion {
    if (_selectedRegionId == null) return null;
    try {
      return _regions.firstWhere((region) => region.regionId == _selectedRegionId);
    } catch (e) {
      return null;
    }
  }

  // Set the list of regions
  void setRegions(List<RegionData> regions) {
    _regions = List.from(regions);
    _selectedRegionId = null;
  }

  // Select a region by its ID
  void selectRegion(String regionId) {
    print('RegionManager: Selecting region $regionId');
    
    // Deselect all regions first
    for (var i = 0; i < _regions.length; i++) {
      if (_regions[i].isSelected) {
        print('RegionManager: Deselecting region ${_regions[i].regionId}');
        _regions[i] = _regions[i].copyWith(isSelected: false);
      }
    }

    // Select the new region
    bool found = false;
    for (var i = 0; i < _regions.length; i++) {
      if (_regions[i].regionId == regionId) {
        print('RegionManager: Found region to select: $regionId');
        _regions[i] = _regions[i].copyWith(isSelected: true);
        _selectedRegionId = regionId;
        found = true;
        break;
      }
    }
    
    if (!found) {
      print('RegionManager: Region $regionId not found in regions list');
    }
    
    // Print the current state of regions
    print('RegionManager: Current regions state:');
    for (var region in _regions) {
      if (region.isSelected) {
        print('RegionManager: Region ${region.regionId} is selected');
      }
    }
    
    // Notify listeners about the change
    notifyListeners();
  }

  // Clear the selection
  void clearSelection() {
    bool hadSelection = _selectedRegionId != null;
    
    for (var i = 0; i < _regions.length; i++) {
      if (_regions[i].isSelected) {
        _regions[i] = _regions[i].copyWith(isSelected: false);
      }
    }
    _selectedRegionId = null;
    
    // Only notify if there was actually a selection to clear
    if (hadSelection) {
      notifyListeners();
    }
  }
  
  // Set hover region with visual feedback
  void setHoverRegion(String? regionId) {
    print('Setting hover region: $regionId, current: ${hoverRegionId.value}');
    
    if (hoverRegionId.value == regionId) return;
    hoverRegionId.value = regionId;
    
    if (regionId == null) {
      print('Clearing hover polygons');
      _hoverPolygons = null;
    } else {
      final hoveredRegion = _regions.cast<RegionData?>().firstWhere(
        (r) => r?.regionId == regionId,
        orElse: () => null,
      );
      
      if (hoveredRegion != null) {
        print('Creating hover polygon for region: ${hoveredRegion.regionId}');
        _hoverPolygons = [
          Polygon(
            points: hoveredRegion.points,
            color: Colors.red.withOpacity(0.4),  // More visible hover color
            borderColor: Colors.red,  // Bright red border
            borderStrokeWidth: 6.0,  // Much thicker border
          ),
        ];
      } else {
        print('Hovered region not found: $regionId');
        _hoverPolygons = null;
      }
    }
    
    notifyListeners();
  }
  
  // Get all polygons with enhanced visual effects
  List<Polygon<RegionHitValue>> getPolygons() {
    return _regions.map((region) {
      final isHovered = region.regionId == hoverRegionId.value;
      final isSelected = region.isSelected;
      
      // Debug logging
      if (isHovered) {
        print('Rendering hover polygon for region: ${region.regionId}');
      }
      if (isSelected) {
        print('Rendering selected polygon for region: ${region.regionId}');
      }
      
      return Polygon(
        points: region.points,
        color: isHovered
            ? Colors.red.withOpacity(0.5)  // Much more visible hover color
            : isSelected
                ? Colors.green.withOpacity(0.3)  // More visible selection color
                : Colors.grey,
        borderColor: isHovered
            ? Colors.red  // Bright red for hover
            : isSelected
                ? Colors.green  // Solid green for selection
                : Colors.brown.withOpacity(0.5),
        borderStrokeWidth: isHovered
            ? 8.0  // Much thicker border for hover
            : isSelected
                ? 6.0  // Thicker border for selection
                : 1.5,
        hitValue: (
          regionId: region.regionId,
          subtitle: 'Region ID: ${region.regionId}',
        ),
      );
    }).toList();
  }

  // Get all polygons including hover effects
  List<Polygon<RegionHitValue>> getAllPolygons() {
    final basePolygons = getPolygons();
    if (_hoverPolygons != null) {
      // Convert hover polygons to have hit values
      final hoverPolygonsWithHitValues = _hoverPolygons!.map((polygon) {
        // Find the region this polygon belongs to
        final hoveredRegion = _regions.firstWhere(
          (r) => r.regionId == hoverRegionId.value,
          orElse: () => _regions.first,
        );
        
        return Polygon<RegionHitValue>(
          points: polygon.points,
          color: polygon.color,
          borderColor: polygon.borderColor,
          borderStrokeWidth: polygon.borderStrokeWidth,
          hitValue: (
            regionId: hoveredRegion.regionId,
            subtitle: 'Region ID: ${hoveredRegion.regionId}',
          ),
        );
      }).toList();
      
      return [
        ...basePolygons,
        ...hoverPolygonsWithHitValues,
      ];
    }
    return basePolygons;
  }
}
