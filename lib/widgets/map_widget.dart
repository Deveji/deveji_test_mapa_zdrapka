import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import '../services/geojson_service.dart';
import '../constants/poland_coordinates.dart';

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
  String loadingStatus = 'Initializing...';
  final centerPoint = polandCenter;

  @override
  void initState() {
    super.initState();
    _initializeGeoData();
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
                OverlayImageLayer(
                  overlayImages: [
                    OverlayImage(
                      bounds: LatLngBounds(
                        LatLng(polandBounds.northEast.latitude + imageAdjustment.top, 
                              polandBounds.northEast.longitude + imageAdjustment.right),
                        LatLng(polandBounds.southWest.latitude - imageAdjustment.bottom, 
                              polandBounds.southWest.longitude - imageAdjustment.left),
                      ),
                      opacity: 1,
                      imageProvider: const AssetImage('lib/widgets/poland.webp'),
                    ),
                  ],
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
                // Counties overlay
                // PolygonLayer(
                //   polygons: counties.map((points) => Polygon(
                //     points: points,
                //     isFilled: true,
                //     color: Colors.grey.withOpacity(0.3),
                //     borderStrokeWidth: 1.0,
                //     borderColor: const Color.fromRGBO(77, 63, 50, 0.5),
                //   )).toList(),
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
