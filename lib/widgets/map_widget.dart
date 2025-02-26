import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/geojson_service.dart';
import '../constants/poland_coordinates.dart';
import '../services/image_cache_service.dart';
import 'progressive_map_image.dart';

class MapWidget extends StatefulWidget {
  const MapWidget({super.key});

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> with WidgetsBindingObserver {
  final mapController = MapController();
  final geoJsonService = GeoJsonService();
  final imageCacheService = ImageCacheService();
  late Future<List<LatLng>> polandBorder;
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
      polandBorder = geoJsonService.extractPolygonPoints().catchError((e) {
        print('Error loading Geo Data: $e');
        throw e;
      });

      print('All data loading initialized');
    } catch (e) {
      print('Error initializing geo data: $e');
      throw Exception('Failed to initialize map data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Object>>(
      future: Future.wait([
        polandBorder,
      ]),
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

        return Stack(
          children: [
            FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: centerPoint,
                initialZoom: 5.75,
                minZoom: 5.6,
                maxZoom: 30,
                cameraConstraint: CameraConstraint.containCenter(
                  bounds: polandBounds,
                ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
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
