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
  
  // Calculate minimum zoom level based on screen height
  double _calculateMinZoomForHeight(BuildContext context, LatLngBounds bounds) {
    final screenHeight = MediaQuery.of(context).size.height;
    final boundsHeight = bounds.north - bounds.south;
    
    // This is a simplified calculation - in a real app you might need to adjust this
    // based on the specific projection and map characteristics
    // The constant factor (0.0009) is an approximation that may need adjustment
    return (screenHeight / (boundsHeight * 111000)) * 0.0009;
  }
  
  // Calculate minimum zoom level based on screen width
  double _calculateMinZoomForWidth(BuildContext context, LatLngBounds bounds) {
    final screenWidth = MediaQuery.of(context).size.width;
    final boundsWidth = bounds.east - bounds.west;
    final latitudeFactor = math.cos(bounds.center.latitude * math.pi / 180);
    
    // Adjust for the fact that longitude degrees vary in distance based on latitude
    // The constant factor (0.0009) is an approximation that may need adjustment
    return (screenWidth / (boundsWidth * 111000 * latitudeFactor)) * 0.0009;
  }
  
  // Handle map events to ensure constraints are enforced
  void _handleMapEvent(MapEvent event) {
    // If needed, we can add additional constraint logic here
    if (event is MapEventMoveEnd) {
      // Additional checks can be added here if needed
      print('Map moved to: ${event.camera.center}, zoom: ${event.camera.zoom}');
    }
  }
  
  void _handleMapTap(LatLng point, List<RegionData> regions) {
    print('Map tapped at: $point');
    
    // Find which region was tapped
    bool regionFound = false;
    for (var region in regions) {
      if (_isPointInPolygon(point, region.points)) {
        print('Region found: ${region.regionId}');
        regionFound = true;
        
        // Select this region
        regionManager.selectRegion(region.regionId);
        
        // Force UI update
        if (mounted) {
          setState(() {}); 
        }
        break;
      }
    }
    
    if (!regionFound) {
      print('No region found at tap point');
    }
  }
  
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    // Implementation of point-in-polygon algorithm
    // This is a simple ray-casting algorithm
    bool isInside = false;
    int i = 0, j = polygon.length - 1;
    
    for (i = 0; i < polygon.length; i++) {
      if ((polygon[i].latitude > point.latitude) != (polygon[j].latitude > point.latitude) &&
          (point.longitude < (polygon[j].longitude - polygon[i].longitude) * 
          (point.latitude - polygon[i].latitude) / 
          (polygon[j].latitude - polygon[i].latitude) + polygon[i].longitude)) {
        isInside = !isInside;
      }
      j = i;
    }
    
    return isInside;
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

        // Get screen size to calculate appropriate min zoom
        final screenSize = MediaQuery.of(context).size;
        final screenAspectRatio = screenSize.width / screenSize.height;
        
        // Calculate the bounds aspect ratio
        final boundsWidth = imageOverlayBounds.east - imageOverlayBounds.west;
        final boundsHeight = imageOverlayBounds.north - imageOverlayBounds.south;
        final boundsAspectRatio = boundsWidth / boundsHeight;
        
        // Calculate minimum zoom based on screen size and bounds
        // This ensures the map always fills the viewport
        double calculatedMinZoom = 5.6; // Default min zoom
        
        // Adjust min zoom based on which dimension is limiting
        if (screenAspectRatio > boundsAspectRatio) {
          // Height is the limiting factor
          calculatedMinZoom = _calculateMinZoomForHeight(context, imageOverlayBounds);
        } else {
          // Width is the limiting factor
          calculatedMinZoom = _calculateMinZoomForWidth(context, imageOverlayBounds);
        }
        
        // Add a small buffer to ensure the image always fills the screen
        calculatedMinZoom += 0.1;

        return Stack(
          children: [
            FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: centerPoint,
                initialZoom: 7.1,
                minZoom: calculatedMinZoom,
                maxZoom: 11,
                // Use a more flexible camera constraint to handle the regions
                cameraConstraint: CameraConstraint.containCenter(
                  bounds: imageOverlayBounds,
                ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onMapEvent: _handleMapEvent,
                onTap: (tapPosition, point) {
                  _handleMapTap(point, regions);
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
                // Region polygons with gray color
                PolygonLayer(
                  polygons: regions.map((region) => Polygon(
                    points: region.points,
                    color: region.isSelected 
                        ? Colors.transparent
                        : Colors.grey,
                    borderColor: region.isSelected 
                        ? Colors.transparent
                        : Colors.brown.withOpacity(0.7),
                    borderStrokeWidth: 3,
                    isFilled: true,
                  )).toList(),
                ),
                
                // Text labels for regions
                MarkerLayer(
                  markers: regions.map((region) => Marker(
                    point: region.center,
                    width: 80,
                    height: 30,
                    child: Center(
                      child: Text(
                        region.regionId,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )).toList(),
                ),
                
                // Brown overlay for Poland border
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: borderPoints,
                      color: Colors.transparent,
                      borderStrokeWidth: 4.0,
                      borderColor: const Color.fromRGBO(77, 63, 50, 1.0),
                    ),
                  ],
                ),
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
