import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import '../services/geojson_service.dart';

// Performance metrics singleton
class PerformanceMetrics {
  static final PerformanceMetrics _instance = PerformanceMetrics._internal();
  factory PerformanceMetrics() => _instance;
  PerformanceMetrics._internal();

  int? imageLoadStartTime;
  int? imageLoadEndTime;
  int? renderStartTime;
  int? renderEndTime;

  void reset() {
    imageLoadStartTime = null;
    imageLoadEndTime = null;
    renderStartTime = null;
    renderEndTime = null;
  }

  String getImageLoadTime() {
    if (imageLoadStartTime == null || imageLoadEndTime == null) return 'N/A';
    return '${(imageLoadEndTime! - imageLoadStartTime!) / 1000} seconds';
  }

  String getRenderTime() {
    if (renderStartTime == null || renderEndTime == null) return 'N/A';
    return '${(renderEndTime! - renderStartTime!) / 1000} seconds';
  }
}

class CachedImageProvider extends ImageProvider<CachedImageProvider> {
  final ui.Image image;

  const CachedImageProvider(this.image);

  @override
  Future<CachedImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<CachedImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(CachedImageProvider key, ImageDecoderCallback decode) {
    return OneFrameImageStreamCompleter(
      SynchronousFuture<ImageInfo>(ImageInfo(image: image)),
    );
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is CachedImageProvider && other.image == image;
  }

  @override
  int get hashCode => image.hashCode;
}

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
  bool shouldRepaint(covariant VoivodeshipLabelPainter oldDelegate) {
    return oldDelegate.voivodeships != voivodeships ||
           oldDelegate.mapController.camera != mapController.camera;
  }
}
class _MapWidgetState extends State<MapWidget> with WidgetsBindingObserver {
  // Static cache for the decoded image
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

  Future<void> _precacheOverlayImage() async {
    if (cachedImage != null) return;

    performanceMetrics.imageLoadStartTime = DateTime.now().millisecondsSinceEpoch;
    
    // Load the asset bytes
    final ByteData data = await rootBundle.load('lib/widgets/poland.webp');
    final Uint8List bytes = data.buffer.asUint8List();
    
    // Decode the image
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    cachedImage = frame.image;
    
    performanceMetrics.imageLoadEndTime = DateTime.now().millisecondsSinceEpoch;
    setState(() {}); // Trigger rebuild with cached image
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeGeoData();
    _precacheOverlayImage();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reset metrics when app comes to foreground
      performanceMetrics.reset();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
                // TileLayer(
                //   urlTemplate: 'https://api.maptiler.com/maps/aquarelle/{z}/{x}/{y}.png?key=RYwixx4ca4fsMuVl1xme',
                //   userAgentPackageName: 'com.deveji.test.mapazdrapka',
                //   tileProvider: CancellableNetworkTileProvider(),
                // ),
                if (isImageVisible)
                  Builder(
                    builder: (context) {
                      performanceMetrics.renderStartTime = DateTime.now().millisecondsSinceEpoch;
                      
                      if (cachedImage == null) {
                        return const SizedBox.shrink();
                      }

                      final overlay = OverlayImageLayer(
                        overlayImages: [
                          OverlayImage(
                            bounds: LatLngBounds(
                              LatLng(bounds.northEast.latitude + top, bounds.northEast.longitude + right),
                              LatLng(bounds.southWest.latitude - bottom, bounds.southWest.longitude - left),
                            ),
                            opacity: 0.8,
                            imageProvider: ResizeImage(
                              CachedImageProvider(cachedImage!),
                              width: cachedImage!.width,
                              height: cachedImage!.height,
                            ),
                          ),
                        ],
                      );

                      performanceMetrics.renderEndTime = DateTime.now().millisecondsSinceEpoch;
                      return overlay;
                    },
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
                    color: Colors.grey.withOpacity(0.8),
                    borderStrokeWidth: 2.0,
                    borderColor: const Color.fromRGBO(77, 63, 50, 0.7),
                  )).toList(),
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
            // Performance metrics display
            Positioned(
              right: 16,
              top: 16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Load: ${performanceMetrics.getImageLoadTime()}'),
                    const SizedBox(height: 4),
                    Text('Render: ${performanceMetrics.getRenderTime()}'),
                  ],
                ),
              ),
            ),
            // Image visibility toggle
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
