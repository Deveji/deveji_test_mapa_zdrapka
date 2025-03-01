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
import 'map/widget/region_info_sheet.dart';

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
  double _currentZoom = 9;

  // Region info state
  String? _eventType;
  List<dynamic>? _hitRegions;
  LatLng? _coords;
  
  // Advanced hover and tap detection
  final LayerHitNotifier<RegionHitValue> _hitNotifier = ValueNotifier(null);
  List<RegionHitValue>? _prevHitValues;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeGeoData();
    _precacheMapImage();
    _hitNotifier.addListener(_updateHoverState);
  }

  void showRegionInfo(BuildContext context, String eventType, List<dynamic> hitRegions, LatLng coords) {
    setState(() {
      _eventType = eventType;
      _hitRegions = hitRegions;
      _coords = coords;
    });
  }

  void _clearRegionInfo() {
    setState(() {
      _eventType = null;
      _hitRegions = null;
      _coords = null;
    });
    regionManager.clearSelection();
  }
  
  void _updateHoverState() {
    final hitValues = _hitNotifier.value?.hitValues.toList();
    if (listEquals(hitValues, _prevHitValues)) return;
    _prevHitValues = hitValues;
    
    if (hitValues != null && hitValues.isNotEmpty) {
      regionManager.setHoverRegion(hitValues.first.regionId);
    } else {
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
    if (state == AppLifecycleState.resumed && !_isImagePrecached) {
      _precacheMapImage();
    }
  }

  Future<void> _precacheMapImage() async {
    try {
      setState(() => loadingStatus = 'Precaching map image...');
      debugPrint('Precaching low-quality map image in MapWidget...');
      await imageCacheService.precacheAssetImage('assets/images/poland.jpg');
      
      if (mounted) {
        setState(() {
          _isImagePrecached = true;
        });
      }
    } catch (e) {
      debugPrint('Error precaching map image: $e');
    }
  }

  void _initializeGeoData() {
    try {
      setState(() => loadingStatus = 'Loading Geo Data...');
      
      mapData = Future.wait([
        geoJsonService.extractPolygonPoints(),
        geoJsonService.extractRegions(),
      ]).then((results) {
        regionManager.setRegions(results[1] as List<RegionData>);
        return results;
      }).catchError((e) {
        print('Error loading Geo Data: $e');
        throw e;
      });
    } catch (e) {
      print('Error initializing geo data: $e');
      throw Exception('Failed to initialize map data: $e');
    }
  }
  
  void _handleMapEvent(MapEvent event) {
    if (event.camera.zoom != _currentZoom) {
      setState(() {
        _currentZoom = event.camera.zoom;
      });
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

        final borderPoints = snapshot.data![0] as List<LatLng>;
        final regions = regionManager.regions.toList();
        
        final imageOverlayBounds = LatLngBounds(
          LatLng(polandBounds.northEast.latitude + imageAdjustment.top, 
                polandBounds.northEast.longitude + imageAdjustment.right),
          LatLng(polandBounds.southWest.latitude - imageAdjustment.bottom, 
                polandBounds.southWest.longitude - imageAdjustment.left),
        );

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
                cameraConstraint: CameraConstraint.contain(
                  bounds: imageOverlayBounds,
                ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onMapEvent: _handleMapEvent,
                onPointerHover: (event, point) {
                  bool foundRegion = false;
                  for (var region in regions) {
                    if (region.containsPointInBoundingBox(point)) {
                      regionManager.setHoverRegion(region.regionId);
                      foundRegion = true;
                      break;
                    }
                  }
                  
                  if (!foundRegion) {
                    regionManager.setHoverRegion(null);
                  }
                },
                onTap: (tapPosition, point) {
                  for (var region in regions) {
                    if (region.containsPointInBoundingBox(point)) {
                      regionManager.selectRegion(region.regionId);
                      showRegionInfo(context, 'Tapped', [region.toHitValue()], point);
                      break;
                    }
                  }
                },
              ),
              children: [
                AdvancedProgressiveMapOverlay(
                  lowQualityImagePath: 'assets/images/poland.jpg',
                  highQualityImagePath: 'assets/images/poland.webp',
                  bounds: imageOverlayBounds,
                  opacity: 1,
                ),
                
                MouseRegion(
                  hitTestBehavior: HitTestBehavior.deferToChild,
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      if (_hitNotifier.value != null && _hitNotifier.value!.hitValues.isNotEmpty) {
                        final hitValues = _hitNotifier.value!.hitValues;
                        final point = _hitNotifier.value!.coordinate;
                        
                        if (hitValues.isNotEmpty) {
                          regionManager.selectRegion(hitValues.first.regionId);
                        }
                        
                        showRegionInfo(context, 'Tapped', hitValues, point);
                      } else {
                        regionManager.clearSelection();
                        _clearRegionInfo();
                      }
                    },
                    onLongPress: () {
                      if (_hitNotifier.value != null && _hitNotifier.value!.hitValues.isNotEmpty) {
                        showRegionInfo(
                          context,
                          'Long pressed',
                          _hitNotifier.value!.hitValues,
                          _hitNotifier.value!.coordinate,
                        );
                      }
                    },
                    onSecondaryTap: () {
                      if (_hitNotifier.value != null && _hitNotifier.value!.hitValues.isNotEmpty) {
                        showRegionInfo(
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
                
                RegionLabelsLayer(
                  regions: regions,
                  zoomLevel: _currentZoom,
                ),
                
                BorderLayer(borderPoints: borderPoints),
              ],
            ),
            // Hover feedback overlay
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
            // Region info bottom sheet
            RegionInfoBottomSheet(
              eventType: _eventType,
              hitRegions: _hitRegions,
              coords: _coords,
              onClose: _clearRegionInfo,
              key: const ValueKey('region_info_sheet'),
            ),
          ],
        );
      },
    );
  }
}
