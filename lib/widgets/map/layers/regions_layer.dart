import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../../services/region_manager.dart';

class RegionsLayer extends StatefulWidget {
  final RegionManager regionManager;
  
  const RegionsLayer({
    super.key,
    required this.regionManager,
  });

  @override
  State<RegionsLayer> createState() => _RegionsLayerState();
}

class _RegionsLayerState extends State<RegionsLayer> {
  @override
  void initState() {
    super.initState();
    // Add a listener to force rebuild when selection changes
    widget.regionManager.addListener(_handleRegionChange);
  }
  
  @override
  void dispose() {
    widget.regionManager.removeListener(_handleRegionChange);
    super.dispose();
  }
  
  void _handleRegionChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: widget.regionManager.hoverRegionId,
      builder: (context, hoverRegionId, child) {
        return RepaintBoundary(
          child: PolygonLayer(
            polygons: widget.regionManager.getPolygons(),
          ),
        );
      },
    );
  }
}
