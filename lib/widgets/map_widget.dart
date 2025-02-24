import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import '../services/geojson_service.dart';

class MapWidget extends StatefulWidget {
  const MapWidget({super.key});

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  final mapController = MapController();
  final geoJsonService = GeoJsonService();
  late Future<List<LatLng>> polandBorder;
  late Future<List<List<LatLng>>> countyPolygons;
  late Future<LatLng> centerPoint;
  late Future<LatLngBounds> mapBounds;
  String loadingStatus = 'Initializing...';
  bool isImageVisible = true;
  final currentZoom = ValueNotifier<double>(5.75); // Initial zoom level

  // Image position adjustment variables
  double top = 0.3;
  double bottom = 3.8;
  double left = 0.2;
  double right = 0.8;

  @override
  void initState() {
    super.initState();
    _initializeGeoData();
  }

  @override
  void dispose() {
    currentZoom.dispose();
    super.dispose();
  }

  void _initializeGeoData() {
    try {
      setState(() => loadingStatus = 'Loading Poland border...');
      polandBorder = geoJsonService.extractPolygonPoints().catchError((e) {
        print('Error loading Poland border: $e');
        throw e;
      });
      
      setState(() => loadingStatus = 'Loading county polygons...');
      countyPolygons = geoJsonService.extractCountyPolygons().catchError((e) {
        print('Error loading counties: $e');
        throw e;
      });

      setState(() => loadingStatus = 'Calculating map center...');
      centerPoint = polandBorder.then((points) {
        return geoJsonService.calculateCenter(points);
      }).catchError((e) {
        print('Error calculating center: $e');
        throw e;
      });

      setState(() => loadingStatus = 'Calculating map bounds...');
      mapBounds = polandBorder.then((points) {
        return geoJsonService.calculateBounds(points);
      }).catchError((e) {
        print('Error calculating bounds: $e');
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
        countyPolygons,
        centerPoint,
        mapBounds,
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
        final counties = snapshot.data![1] as List<List<LatLng>>;
        final center = snapshot.data![2] as LatLng;
        final bounds = snapshot.data![3] as LatLngBounds;

        return Stack(
          children: [
            FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 5.75,
                minZoom: 5.6,
                maxZoom: 11,
                onMapEvent: (MapEvent event) {
                  if (event is MapEventMove) {
                    currentZoom.value = event.camera.zoom;
                  }
                },
                cameraConstraint: CameraConstraint.containCenter(
                  bounds: bounds,
                ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                // TileLayer(
                //   urlTemplate: 'https://api.maptiler.com/maps/aquarelle/{z}/{x}/{y}.png?key=RYwixx4ca4fsMuVl1xme',
                //   userAgentPackageName: 'com.deveji.test.mapazdrapka',
                //   tileProvider: CancellableNetworkTileProvider(),
                // ),
                if (isImageVisible)
                  OverlayImageLayer(
                    overlayImages: [
                      OverlayImage(
                        bounds: LatLngBounds(
                          LatLng(bounds.northEast.latitude + top, bounds.northEast.longitude + right),
                          LatLng(bounds.southWest.latitude - bottom, bounds.southWest.longitude - left),
                        ),
                        opacity: 0.8,
                        imageProvider: const AssetImage('lib/widgets/poland.webp'),
                      ),
                    ],
                  ),
                // Gray overlay for the rest of the world
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: const [
                        LatLng(85, -180),  // Top-left of the world
                        LatLng(85, 180),   // Top-right of the world
                        LatLng(-85, 180),  // Bottom-right of the world
                        LatLng(-85, -180), // Bottom-left of the world
                      ],
                      color: const Color.fromRGBO(208, 194, 183, 1.0),
                      holePointsList: [borderPoints],
                      isFilled: true,
                    ),
                  ],
                ),
                // Counties overlay
                PolygonLayer(
                  polygons: counties.map((points) => Polygon(
                    points: points,
                    isFilled: true,
                    color: Colors.grey.withOpacity(0.3),
                    borderStrokeWidth: 1.5,
                    borderColor: const Color.fromRGBO(77, 63, 50, 0.5),
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
                  mapController.move(center, 5.75);
                  currentZoom.value = 5.75;
                },
                child: const Icon(Icons.center_focus_strong),
              ),
            ),
            // Zoom level display
            Positioned(
              left: 16,
              bottom: 16,
              child: ValueListenableBuilder<double>(
                valueListenable: currentZoom,
                builder: (context, zoom, _) {
                  return ZoomDisplay(zoom: zoom);
                },
              ),
            ),
            Positioned(
              left: 16,
              top: 16,
              child: FloatingActionButton(
                onPressed: () {
                  setState(() {
                    isImageVisible = !isImageVisible;
                  });
                },
                child: Icon(isImageVisible ? Icons.visibility_off : Icons.visibility),
              ),
            ),
          ],
        );
      },
    );
  }
}

class ZoomDisplay extends StatelessWidget {
  final double zoom;

  const ZoomDisplay({super.key, required this.zoom});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Text(
        'Zoom: ${zoom.toStringAsFixed(2)}',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
