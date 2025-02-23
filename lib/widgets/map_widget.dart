import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import '../constants/poland_coordinates.dart';

class MapWidget extends StatefulWidget {
  const MapWidget({super.key});

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  final mapController = MapController();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: polandCenter,
            initialZoom: 5.75,
            minZoom: 5.6,
            maxZoom: 30,
            cameraConstraint: CameraConstraint.containCenter(
              bounds: LatLngBounds(northEast, southWest),
            ),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://api.maptiler.com/maps/aquarelle/{z}/{x}/{y}.png?key=RYwixx4ca4fsMuVl1xme',
              userAgentPackageName: 'com.deveji.test.mapazdrapka',
              tileProvider: CancellableNetworkTileProvider(),
            ),
            OverlayImageLayer(
              overlayImages: [
                OverlayImage(
                  bounds: LatLngBounds(
                    LatLng(northEast.latitude, northEast.longitude + 0.3),
                    LatLng(southWest.latitude - (northEast.latitude - southWest.latitude) * 0.6, southWest.longitude),
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
                  color: Color.fromRGBO(208, 194, 183, 1.0),
                  holePointsList: [polandBorder],
                  isFilled: true,
                ),
              ],
            ),
            // Brown overlay for Poland
            PolygonLayer(
              polygons: [
                Polygon(
                  points: [...polandBorder],
                  borderStrokeWidth: 4.0,
                  borderColor: Color.fromRGBO(77, 63, 50, 1.0),
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
              mapController.move(polandCenter, 5.75);
            },
            child: const Icon(Icons.center_focus_strong),
          ),
        ),
      ],
    );
  }
}
