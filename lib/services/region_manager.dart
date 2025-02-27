import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/region_data.dart';

class RegionManager extends ChangeNotifier {
  static final RegionManager _instance = RegionManager._internal();
  factory RegionManager() => _instance;
  RegionManager._internal();

  List<RegionData> _regions = [];
  String? _selectedRegionId;
  
  // For hover effects
  final ValueNotifier<String?> hoverRegionId = ValueNotifier(null);

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
  
  // Set hover region
  void setHoverRegion(String? regionId) {
    hoverRegionId.value = regionId;
  }
  
  // Get polygons for rendering
  List<Polygon> getPolygons() {
    return _regions.map((region) {
      final isHovered = region.regionId == hoverRegionId.value;
      
      return Polygon(
        points: region.points,
        color: region.isSelected 
            ? Colors.blue.withOpacity(0.3)
            : Colors.grey.withOpacity(0.5),
        borderColor: isHovered
            ? Colors.blue
            : region.isSelected
                ? Colors.blue.withOpacity(0.7)
                : Colors.brown.withOpacity(0.7),
        borderStrokeWidth: isHovered || region.isSelected ? 3.0 : 1.0,
        isFilled: true,
      );
    }).toList();
  }
}
