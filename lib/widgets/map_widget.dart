import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';
import '../services/geojson_service.dart';

class MapWidget extends StatefulWidget {
  const MapWidget({super.key});

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class VoivodeshipLabelPainter extends CustomPainter {
  final List<VoivodeshipData> voivodeships;
  final MapController mapController;

  VoivodeshipLabelPainter({
    required this.voivodeships,
    required this.mapController,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var voivodeship in voivodeships) {
      final center = _calculatePolygonCenter(voivodeship.points);
      final screenPoint = mapController.camera.latLngToScreenPoint(center);
      
      if (screenPoint != null) {
        final textSpan = TextSpan(
          text: voivodeship.name,
          style: const TextStyle(
            color: Color.fromRGBO(77, 63, 50, 1.0),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        );
        
        final textPainter = TextPainter(
          text: textSpan,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        );

        textPainter.layout();
        
        final offset = Offset(
          screenPoint.x - (textPainter.width / 2),
          screenPoint.y - (textPainter.height / 2),
        );
        
        textPainter.paint(canvas, offset);
      }
    }
  }

  LatLng _calculatePolygonCenter(List<LatLng> points) {
    double totalLat = 0;
    double totalLng = 0;
    
    for (var point in points) {
      totalLat += point.latitude;
      totalLng += point.longitude;
    }
    
    return LatLng(
      totalLat / points.length,
      totalLng / points.length,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _MapWidgetState extends State<MapWidget> with WidgetsBindingObserver {
  Color _getVoivodeshipColor(VoivodeshipData voivodeship) {
    if (voivodeship == selectedVoivodeship) {
      return Colors.blue.withOpacity(0.6);
    }
    if (voivodeship == hoveredVoivodeship) {
      return Colors.lightBlue.withOpacity(0.4);
    }
    return Colors.grey.withOpacity(0.8);
  }

  Color _getVoivodeshipBorderColor(VoivodeshipData voivodeship) {
    if (voivodeship == selectedVoivodeship || voivodeship == hoveredVoivodeship) {
      return Colors.blue;
    }
    return const Color.fromRGBO(77, 63, 50, 0.7);
  }

  void _showVoivodeshipInfo(VoivodeshipData voivodeship) {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                voivodeship.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('Selected voivodeship: ${voivodeship.name}'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => selectedVoivodeship = null);
                    Navigator.pop(context);
                  },
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Point in polygon check using ray casting algorithm
  bool _isPointInPolygon(LatLng point, List<LatLng> polygonPoints) {
    var inside = false;
    var j = polygonPoints.length - 1;
    
    for (var i = 0; i < polygonPoints.length; i++) {
      if (((polygonPoints[i].latitude > point.latitude) != 
           (polygonPoints[j].latitude > point.latitude)) &&
          (point.longitude < (polygonPoints[j].longitude - polygonPoints[i].longitude) * 
           (point.latitude - polygonPoints[i].latitude) / 
           (polygonPoints[j].latitude - polygonPoints[i].latitude) + 
           polygonPoints[i].longitude)) {
        inside = !inside;
      }
      j = i;
    }
    
    return inside;
  }

  VoivodeshipData? hoveredVoivodeship;
  VoivodeshipData? selectedVoivodeship;
  static ui.Image? cachedImage;
  final performanceMetrics = PerformanceMetrics();
  final mapController = MapController();
  final geoJsonService = GeoJsonService();
  late Future<List<LatLng>> polandBorder;
  late Future<List<List<LatLng>>> countyPolygons;
  late Future<List<VoivodeshipData>> voivodeshipData;
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

      setState(() => loadingStatus = 'Loading voivodeships...');
      voivodeshipData = geoJsonService.extractVoivodeshipPolygons().catchError((e) {
        print('Error loading voivodeships: $e');
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
        voivodeshipData,
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
        final voivodeships = snapshot.data![2] as List<VoivodeshipData>;
        final center = snapshot.data![3] as LatLng;
        final bounds = snapshot.data![4] as LatLngBounds;

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
                // Voivodeships overlay
                PolygonLayer(
                  polygons: voivodeships.map((data) => Polygon(
                    points: data.points,
                    isFilled: true,
                    color: _getVoivodeshipColor(data),
                    borderStrokeWidth: 2.0,
                    borderColor: _getVoivodeshipBorderColor(data),
                  )).toList(),
                ),
                // Hit testing layer
                MouseRegion(
                  hitTestBehavior: HitTestBehavior.translucent,
                  onHover: (event) {
                    final point = mapController.camera.pointToLatLng(
                      Point(event.localPosition.dx, event.localPosition.dy)
                    );
                    if (point == null) return;

                    VoivodeshipData? hitVoivodeship;
                    for (var voivodeship in voivodeships) {
                      if (_isPointInPolygon(point, voivodeship.points)) {
                        hitVoivodeship = voivodeship;
                        break;
                      }
                    }

                    if (hitVoivodeship != hoveredVoivodeship) {
                      setState(() => hoveredVoivodeship = hitVoivodeship);
                    }
                  },
                  onExit: (_) {
                    if (hoveredVoivodeship != null) {
                      setState(() => hoveredVoivodeship = null);
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapUp: (details) {
                      final point = mapController.camera.pointToLatLng(
                        Point(details.localPosition.dx, details.localPosition.dy)
                      );
                      if (point == null) return;

                      for (var voivodeship in voivodeships) {
                        if (_isPointInPolygon(point, voivodeship.points)) {
                          setState(() => selectedVoivodeship = voivodeship);
                          _showVoivodeshipInfo(voivodeship);
                          break;
                        }
                      }
                    },
                    child: Container(color: Colors.transparent),
                  ),
                ),
                // Voivodeship labels
                ValueListenableBuilder<double>(
                  valueListenable: currentZoom,
                  builder: (context, zoom, _) {
                    return zoom >= 6.5 ? CustomPaint(
                      size: Size(MediaQuery.of(context).size.width, MediaQuery.of(context).size.height),
                      painter: VoivodeshipLabelPainter(
                        voivodeships: voivodeships,
                        mapController: mapController,
                      ),
                    ) : const SizedBox.shrink();
                  },
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
