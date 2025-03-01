import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/geojson_service.dart';
import '../constants/config.dart';
import '../services/image_cache_service.dart';
import '../services/region_manager.dart';
import '../models/region_data.dart';
import 'map/utils/progressive_map_image.dart';
import 'map/layers/regions_layer.dart';
import 'map/layers/region_labels_layer.dart';
import 'map/layers/border_layer.dart';
import 'map/utils/map_calculation_helper.dart';
import 'map/modals/region_info_modal.dart';

class MapWidget extends StatefulWidget {
  const MapWidget({super.key});

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> with WidgetsBindingObserver {
  final mapController = MapController();
  final geoJsonService = GeoJsonService();
  final regionManager = RegionManager();
  final imageCacheService = ImageCacheService();
  late Future<List<Object>> mapData;
  String loadingStatus = 'Initializing...';
  final centerPoint = polandCenter;
  bool _isImagePrecached = false;
  double _currentZoom = 9; // Track current zoom level
  
  // Advanced hover and tap detection
  final LayerHitNotifier<RegionHitValue> _hitNotifier = ValueNotifier(null);
  List<RegionHitValue>? _prevHitValues;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeGeoData();
    _precacheMapImage();
    
    // Add listener to the hit notifier to update hover state
    _hitNotifier.addListener(_updateHoverState);
  }
  
  void _updateHoverState() {
    final hitValues = _hitNotifier.value?.hitValues.toList();
    
    // Debug logging
    print('Hit values: $hitValues');
    print('Previous hit values: $_prevHitValues');
    print('Hit coordinate: ${_hitNotifier.value?.coordinate}');
    
    // Skip if the hit values haven't changed
    if (listEquals(hitValues, _prevHitValues)) return;
    _prevHitValues = hitValues;
    
    // Update hover state in region manager
    if (hitValues != null && hitValues.isNotEmpty) {
      print('Setting hover region: ${hitValues.first.regionId}');
      regionManager.setHoverRegion(hitValues.first.regionId);
    } else {
      print('Clearing hover region');
      regionManager.setHoverRegion(null);
    }
  }

  @override
  void dispose() {
    _hitNotifier.removeListener(_updateHoverState);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app resumes from background, ensure the image is still cached
    if (state == AppLifecycleState.resumed && !_isImagePrecached) {
      _precacheMapImage();
    }
  }

  Future<void> _precacheMapImage() async {
    try {
      setState(() => loadingStatus = 'Precaching map image...');
      
      // First precache the low-quality image
      debugPrint('Precaching low-quality map image in MapWidget...');
      await imageCacheService.precacheAssetImage('assets/images/poland.jpg');
      
      if (mounted) {
        setState(() {
          _isImagePrecached = true;
        });
      }
      
      // The high-quality image will be loaded by the AdvancedProgressiveMapOverlay
    } catch (e) {
      debugPrint('Error precaching map image: $e');
    }
  }

  void _initializeGeoData() {
    try {
      setState(() => loadingStatus = 'Loading Geo Data...');
      
      // Load both Poland border and regions
      mapData = Future.wait([
        geoJsonService.extractPolygonPoints(),
        geoJsonService.extractRegions(),
      ]).then((results) {
        // Store regions in the RegionManager
        regionManager.setRegions(results[1] as List<RegionData>);
        return results;
      }).catchError((e) {
        print('Error loading Geo Data: $e');
        throw e;
      });

      print('All data loading initialized');
    } catch (e) {
      print('Error initializing geo data: $e');
      throw Exception('Failed to initialize map data: $e');
    }
  }
  
  // Map calculation methods moved to MapCalculationHelper class
  
  // Handle map events to ensure constraints are enforced
  void _handleMapEvent(MapEvent event) {
    // Update zoom level for any event that changes the camera
    if (event.camera.zoom != _currentZoom) {
      print('Zoom changed to: ${event.camera.zoom}');
      setState(() {
        _currentZoom = event.camera.zoom;
      });
    }
    
    // Additional logging for move end events
    if (event is MapEventMoveEnd) {
      print('Map moved to: ${event.camera.center}, zoom: ${event.camera.zoom}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Object>>(
      future: mapData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(loadingStatus),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Text('No data available'),
          );
        }

        print('All data loaded successfully');
        final borderPoints = snapshot.data![0] as List<LatLng>;
        
        // Get regions from RegionManager to ensure we have the latest selection state
        final regions = regionManager.regions.toList();
        
        // Calculate the image overlay bounds with adjustments
        final imageOverlayBounds = LatLngBounds(
          LatLng(polandBounds.northEast.latitude + imageAdjustment.top, 
                polandBounds.northEast.longitude + imageAdjustment.right),
          LatLng(polandBounds.southWest.latitude - imageAdjustment.bottom, 
                polandBounds.southWest.longitude - imageAdjustment.left),
        );

        // Calculate minimum zoom using the helper class
        final calculatedMinZoom = MapCalculationHelper.calculateMinZoom(context, imageOverlayBounds);

        return Stack(
          children: [
            FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: centerPoint,
                initialZoom: 7.1,
                minZoom: calculatedMinZoom,
                maxZoom: 11,
                // Configure map bounds
                cameraConstraint: CameraConstraint.contain(
                  bounds: imageOverlayBounds,
                ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onMapEvent: _handleMapEvent,
                // Add direct hover detection as a fallback
                onPointerHover: (event, point) {
                  print('Direct hover detected at: $point');
                  // This is a fallback in case the hit notifier doesn't work
                  bool foundRegion = false;
                  for (var region in regions) {
                    if (region.containsPointInBoundingBox(point)) {
                      print('Direct hover: region in bounding box: ${region.regionId}');
                      regionManager.setHoverRegion(region.regionId);
                      foundRegion = true;
                      break;
                    }
                  }
                  
                  // If no region was found, clear the hover state
                  if (!foundRegion) {
                    print('Direct hover: no region found, clearing hover state');
                    regionManager.setHoverRegion(null);
                  }
                },
                // Add direct tap detection as a fallback
                onTap: (tapPosition, point) {
                  print('Direct tap detected at: $point');
                  // This is a fallback in case the hit notifier doesn't work
                  for (var region in regions) {
                    if (region.containsPointInBoundingBox(point)) {
                      print('Direct tap: region in bounding box: ${region.regionId}');
                      regionManager.selectRegion(region.regionId);
                      showRegionInfoModal(context, 'Tapped', [region.toHitValue()], point);
                      break;
                    }
                  }
                },
              ),
              children: [
                // Progressive map overlay with low-quality image loading first
                AdvancedProgressiveMapOverlay(
                  lowQualityImagePath: 'assets/images/poland.jpg',
                  highQualityImagePath: 'assets/images/poland.webp',
                  bounds: LatLngBounds(
                    LatLng(polandBounds.northEast.latitude + imageAdjustment.top,
                          polandBounds.northEast.longitude + imageAdjustment.right),
                    LatLng(polandBounds.southWest.latitude - imageAdjustment.bottom,
                          polandBounds.southWest.longitude - imageAdjustment.left),
                  ),
                  opacity: 1,
                ),
                
                // Enhanced mouse interaction with MouseRegion and GestureDetector
                MouseRegion(
                  hitTestBehavior: HitTestBehavior.deferToChild,
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      if (_hitNotifier.value != null && _hitNotifier.value!.hitValues.isNotEmpty) {
                        final hitValues = _hitNotifier.value!.hitValues;
                        final point = _hitNotifier.value!.coordinate;
                        
                        // Select the region
                        if (hitValues.isNotEmpty) {
                          regionManager.selectRegion(hitValues.first.regionId);
                        }
                        
                        // Show modal with region information
                        showRegionInfoModal(context, 'Tapped', hitValues, point);
                      } else {
                        // Clear selection if tapped outside any region
                        regionManager.clearSelection();
                      }
                    },
                    onLongPress: () {
                      if (_hitNotifier.value != null && _hitNotifier.value!.hitValues.isNotEmpty) {
                        showRegionInfoModal(
                          context,
                          'Long pressed',
                          _hitNotifier.value!.hitValues,
                          _hitNotifier.value!.coordinate,
                        );
                      }
                    },
                    onSecondaryTap: () {
                      if (_hitNotifier.value != null && _hitNotifier.value!.hitValues.isNotEmpty) {
                        showRegionInfoModal(
                          context,
                          'Secondary tapped',
                          _hitNotifier.value!.hitValues,
                          _hitNotifier.value!.coordinate,
                        );
                      }
                    },
                    child: RegionsLayer(
                      regionManager: regionManager,
                      hitNotifier: _hitNotifier,
                    ),
                  ),
                ),
                
                // Text labels for regions with zoom-based scaling
                RegionLabelsLayer(
                  regions: regions,
                  zoomLevel: _currentZoom, // Use tracked zoom level
                ),
                
                // Brown overlay for Poland border
                BorderLayer(borderPoints: borderPoints),
              ],
            ),
            // Enhanced hover feedback overlay with animation
            Positioned(
              top: 16,
              right: 16,
              child: ValueListenableBuilder<String?>(
                valueListenable: regionManager.hoverRegionId,
                builder: (context, hoverId, child) {
                  if (hoverId == null) return const SizedBox.shrink();
                  
                  final region = regionManager.regions.firstWhere(
                    (r) => r.regionId == hoverId,
                    orElse: () => regionManager.regions.first,
                  );

                  return AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: 1.0,
                    child: Card(
                      key: ValueKey(hoverId),
                      color: Colors.white.withOpacity(0.9),
                      elevation: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Region: ${region.regionId}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap for more details',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
