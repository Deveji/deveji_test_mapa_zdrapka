import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/region_data.dart';
import 'scratch_storage_service.dart';

class RegionManager extends ChangeNotifier {
  static final RegionManager _instance = RegionManager._internal();
  factory RegionManager() => _instance;
  RegionManager._internal() {
    _loadScratchedRegions();
  }

  final _scratchStorage = ScratchStorageService();

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

  Future<void> _loadScratchedRegions() async {
    await _scratchStorage.init();
    final scratchedIds = _scratchStorage.getScratched();
    
    for (var i = 0; i < _regions.length; i++) {
      if (scratchedIds.contains(_regions[i].regionId)) {
        _regions[i] = _regions[i].copyWith(isScratched: true);
      }
    }
    notifyListeners();
  }

  // Set the list of regions
  void setRegions(List<RegionData> regions) {
    _regions = List.from(regions);
    _selectedRegionId = null;
    _loadScratchedRegions(); // Load scratched state after setting regions
  }

  // Scratch a region by its ID
  Future<void> scratchRegion(String regionId) async {
    print('RegionManager: Scratching region $regionId');
    
    bool found = false;
    for (var i = 0; i < _regions.length; i++) {
      if (_regions[i].regionId == regionId) {
        print('RegionManager: Found region to scratch: $regionId');
        // Set scratched but maintain selection state
        _regions[i] = _regions[i].copyWith(
          isScratched: true,
          isSelected: _regions[i].isSelected, // Maintain current selection state
        );
        
        // Clear hover effects if this region is being hovered
        if (hoverRegionId.value == regionId) {
          _hoverPolygons = null;
        }
        
        found = true;
        break;
      }
    }
    
    if (!found) {
      print('RegionManager: Region $regionId not found in regions list');
    } else {
      // Save to persistent storage
      await _scratchStorage.saveScratched(regionId);
    }
    
    notifyListeners();
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
        if (!hoveredRegion.isScratched) {
          _hoverPolygons = [
            Polygon(
              points: hoveredRegion.points,
              color: Colors.grey[300]!,  // light gray for hover
              borderColor: Colors.brown.withOpacity(0.5),  // default border
              borderStrokeWidth: 1.5,  // default border width
            ),
          ];
        }
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
        // Always transparent if scratched, regardless of hover/selection state
        color: region.isScratched
            ? Colors.transparent
            : isHovered
                ? Colors.grey[300]!  // light gray for hover
                : isSelected
                    ? Colors.grey[300]!  // light gray for selection
                    : Colors.grey,  // default gray
        // Maintain selection border even when scratched
        borderColor: isSelected
            ? Colors.grey[800]!  // dark border for selection
            : Colors.brown.withOpacity(0.5),  // default border
        borderStrokeWidth: isSelected
            ? 6.0  // Thicker border for selection
            : 1.5,  // default border width
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
