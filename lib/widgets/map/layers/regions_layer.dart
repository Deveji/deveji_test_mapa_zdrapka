import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../../services/region_manager.dart';
import '../../../models/region_data.dart';

typedef RegionHit = ({String regionId, String name});

/// Caches polygon data to prevent recalculation
class _CachedPolygonData {
  final List<Polygon<RegionHitValue>> polygons;
  final String? hoverId;
  final String? selectedId;
  final List<String> scratchedIds;
  final double timestamp;

  _CachedPolygonData({
    required this.polygons,
    required this.hoverId,
    required this.selectedId,
    required this.scratchedIds,
    required this.timestamp,
  });

  bool isStale(String? currentHoverId, String? currentSelectedId, List<String> currentScratchedIds) {
    if (hoverId != currentHoverId || selectedId != currentSelectedId) {
      return true;
    }
    
    // Check if scratched regions have changed
    if (scratchedIds.length != currentScratchedIds.length) {
      return true;
    }
    
    for (final id in currentScratchedIds) {
      if (!scratchedIds.contains(id)) {
        return true;
      }
    }
    
    return false;
  }

  bool isExpired() {
    return DateTime.now().millisecondsSinceEpoch - timestamp > 5000; // 5 seconds cache
  }
}

class RegionsLayer extends StatefulWidget {
  final RegionManager regionManager;
  final LayerHitNotifier<RegionHitValue>? hitNotifier;
  
  const RegionsLayer({
    super.key,
    required this.regionManager,
    this.hitNotifier,
  });

  @override
  State<RegionsLayer> createState() => _RegionsLayerState();
}

class _RegionsLayerState extends State<RegionsLayer> {
  _CachedPolygonData? _cachedData;
  Timer? _cleanupTimer;

  @override
  void initState() {
    super.initState();
    // Add a listener to force rebuild when selection changes
    widget.regionManager.addListener(_handleRegionChange);
    // Setup periodic cache cleanup
    _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_cachedData?.isExpired() ?? false) {
        setState(() => _cachedData = null);
      }
    });
  }
  
  @override
  void dispose() {
    widget.regionManager.removeListener(_handleRegionChange);
    _cleanupTimer?.cancel();
    super.dispose();
  }
  
  void _handleRegionChange() {
    // Only trigger rebuild if the cache is stale
    if (mounted && _isCacheStale()) {
      setState(() => _cachedData = null);
    }
  }

  bool _isCacheStale() {
    if (_cachedData == null) return true;
    
    final currentHoverId = widget.regionManager.hoverRegionId.value;
    final selectedRegion = widget.regionManager.selectedRegion;
    
    // Get all scratched region IDs
    final scratchedIds = widget.regionManager.regions
        .where((region) => region.isScratched)
        .map((region) => region.regionId)
        .toList();
    
    // Always consider cache stale if we have scratched regions
    // This ensures immediate updates when scratching
    if (scratchedIds.isNotEmpty) {
      return true;
    }
    
    return _cachedData!.isStale(
      currentHoverId,
      selectedRegion?.regionId,
      scratchedIds,
    ) || _cachedData!.isExpired();
  }

  List<Polygon<RegionHitValue>> _createPolygons() {
    final currentHoverId = widget.regionManager.hoverRegionId.value;
    final selectedRegion = widget.regionManager.selectedRegion;
    
    // Get all scratched region IDs
    final scratchedIds = widget.regionManager.regions
        .where((region) => region.isScratched)
        .map((region) => region.regionId)
        .toList();
    
    // Create new cached data
    final polygons = widget.regionManager.getAllPolygons();
    _cachedData = _CachedPolygonData(
      polygons: polygons,
      hoverId: currentHoverId,
      selectedId: selectedRegion?.regionId,
      scratchedIds: scratchedIds,
      timestamp: DateTime.now().millisecondsSinceEpoch.toDouble(),
    );
    
    return polygons;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ValueListenableBuilder<String?>(
        valueListenable: widget.regionManager.hoverRegionId,
        builder: (context, hoverValue, child) {
          final polygons = !_isCacheStale()
              ? _cachedData!.polygons
              : _createPolygons();

          return PolygonLayer(
            key: ValueKey('polygon_layer_${hoverValue ?? 'none'}'),
            polygons: polygons,
            hitNotifier: widget.hitNotifier,
          );
        },
      ),
    );
  }
}
