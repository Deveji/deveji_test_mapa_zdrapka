import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/geojson_service.dart';
import '../constants/poland_coordinates.dart';
import '../services/image_cache_service.dart';
import '../services/region_manager.dart';
import '../models/region_data.dart';
import 'progressive_map_image.dart';
import 'map/layers/regions_layer.dart';
import 'map/layers/region_labels_layer.dart';
import 'map/layers/border_layer.dart';
import 'map/utils/point_in_polygon_util.dart';
import 'map/utils/map_calculation_helper.dart';

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
  double _currentZoom = 7.1; // Track current zoom level

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeGeoData();
    _precacheMapImage();
  }

  @override
  void dispose() {
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
      await imageCacheService.precacheAssetImage('lib/widgets/poland.jpg');
      
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
  
  void _handleMapTap(LatLng point, List<RegionData> regions) {
    print('Map tapped at: $point');
    
    // Find which region was tapped using the utility class
    final tappedRegion = PointInPolygonUtil.findRegionAt(point, regions);
    
    if (tappedRegion != null) {
      print('Region found: ${tappedRegion.regionId}');
      
      // Select this region
      regionManager.selectRegion(tappedRegion.regionId);
      
      // Clear hover state
      regionManager.setHoverRegion(null);
      
      // Force UI update to ensure selection is visible immediately
      setState(() {});
    } else {
      print('No region found at tap point');
      
      // Clear selection and hover
      regionManager.clearSelection();
      regionManager.setHoverRegion(null);
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
                onTap: (tapPosition, point) => _handleMapTap(point, regions),
                // Handle hover through taps for now
                onSecondaryTap: (tapPosition, point) {
                  if (mounted) {
                    final hoveredRegion = PointInPolygonUtil.findRegionAt(point, regions);
                    regionManager.setHoverRegion(hoveredRegion?.regionId);
                  }
                },
              ),
              children: [
                // TileLayer(
                //   urlTemplate: 'https://api.maptiler.com/maps/toner-v2/{z}/{x}/{y}.png?key=RYwixx4ca4fsMuVl1xme',
                //   userAgentPackageName: 'com.deveji.test.mapazdrapka',
                //   tileProvider: CancellableNetworkTileProvider(),
                // ),

                // Progressive map overlay with low-quality image loading first
                AdvancedProgressiveMapOverlay(
                  lowQualityImagePath: 'lib/widgets/poland.jpg',
                  highQualityImagePath: 'lib/widgets/poland.webp',
                  bounds: LatLngBounds(
                    LatLng(polandBounds.northEast.latitude + imageAdjustment.top, 
                          polandBounds.northEast.longitude + imageAdjustment.right),
                    LatLng(polandBounds.southWest.latitude - imageAdjustment.bottom, 
                          polandBounds.southWest.longitude - imageAdjustment.left),
                  ),
                  opacity: 1,
                ),
                // Gray overlay for the rest of the world
                // PolygonLayer(
                //   polygons: [
                //     Polygon(
                //       points: const [
                //         LatLng(85, -180),  // Top-left of the world
                //         LatLng(85, 180),   // Top-right of the world
                //         LatLng(-85, 180),  // Bottom-right of the world
                //         LatLng(-85, -180), // Bottom-left of the world
                //       ],
                //       color: const Color.fromRGBO(208, 194, 183, 1.0),
                //       holePointsList: [borderPoints],
                //       isFilled: true,
                //     ),
                //   ],
                // ),
                // Region polygons layer
                RegionsLayer(regionManager: regionManager),
                
                // Text labels for regions with zoom-based scaling
                RegionLabelsLayer(
                  regions: regions,
                  zoomLevel: _currentZoom, // Use tracked zoom level
                ),
                
                // Brown overlay for Poland border
                BorderLayer(borderPoints: borderPoints),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                onPressed: () {
                  mapController.move(centerPoint, 5.75);
                },
                child: const Icon(Icons.center_focus_strong),
              ),
            ),
          ],
        );
      },
    );
  }
}
