import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/image_cache_service.dart';

/// A widget that implements progressive image loading for map overlays.
/// It first displays a low-quality image and then transitions to a high-quality image
/// once it's loaded, providing a better user experience with large images.
class ProgressiveMapImage extends StatefulWidget {
  final String lowQualityImagePath;
  final String highQualityImagePath;
  final LatLngBounds bounds;
  final double opacity;
  final Duration fadeInDuration;

  const ProgressiveMapImage({
    Key? key,
    required this.lowQualityImagePath,
    required this.highQualityImagePath,
    required this.bounds,
    this.opacity = 1.0,
    this.fadeInDuration = const Duration(milliseconds: 500),
  }) : super(key: key);

  @override
  State<ProgressiveMapImage> createState() => _ProgressiveMapImageState();
}

class _ProgressiveMapImageState extends State<ProgressiveMapImage> {
  final ImageCacheService _cacheService = ImageCacheService();
  bool _isLowQualityLoaded = false;
  bool _isHighQualityLoaded = false;
  bool _hasError = false;
  late ImageProvider _lowQualityImageProvider;
  late ImageProvider _highQualityImageProvider;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    // Start loading the low-quality image
    _loadLowQualityImage();
    
    // Start loading the high-quality image in the background
    _loadHighQualityImage();
  }

  Future<void> _loadLowQualityImage() async {
    try {
      // Create the image provider
      _lowQualityImageProvider = AssetImage(widget.lowQualityImagePath);
      
      // Precache the image
      await precacheImage(_lowQualityImageProvider, context);
      
      if (mounted) {
        setState(() {
          _isLowQualityLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading low-quality image: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  Future<void> _loadHighQualityImage() async {
    try {
      // Create the image provider
      _highQualityImageProvider = AssetImage(widget.highQualityImagePath);
      
      // Precache the image
      await precacheImage(_highQualityImageProvider, context);
      
      if (mounted) {
        setState(() {
          _isHighQualityLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading high-quality image: $e');
      // Don't set _hasError here, as we still have the low-quality image
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError && !_isLowQualityLoaded && !_isHighQualityLoaded) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text('Failed to load map image'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _hasError = false;
                });
                _loadImages();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // If high-quality image is loaded, show it with a fade-in animation
    if (_isHighQualityLoaded) {
      return AnimatedOpacity(
        opacity: 1.0,
        duration: widget.fadeInDuration,
        child: OverlayImage(
          bounds: widget.bounds,
          opacity: widget.opacity,
          imageProvider: _highQualityImageProvider,
        ),
      );
    }

    // If only low-quality image is loaded, show it
    if (_isLowQualityLoaded) {
      return OverlayImage(
        bounds: widget.bounds,
        opacity: widget.opacity,
        imageProvider: _lowQualityImageProvider,
      );
    }

    // If no images are loaded yet, show a loading indicator
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text('Loading map...'),
        ],
      ),
    );
  }
}

/// A layer that manages progressive loading of map overlay images.
/// This widget handles the loading of both low and high-quality images
/// and provides a smooth transition between them.
class ProgressiveMapOverlay extends StatefulWidget {
  final String lowQualityImagePath;
  final String highQualityImagePath;
  final LatLngBounds bounds;
  final double opacity;

  const ProgressiveMapOverlay({
    Key? key,
    required this.lowQualityImagePath,
    required this.highQualityImagePath,
    required this.bounds,
    this.opacity = 1.0,
  }) : super(key: key);

  @override
  State<ProgressiveMapOverlay> createState() => _ProgressiveMapOverlayState();
}

class _ProgressiveMapOverlayState extends State<ProgressiveMapOverlay> {
  @override
  Widget build(BuildContext context) {
    return OverlayImageLayer(
      overlayImages: [
        OverlayImage(
          bounds: widget.bounds,
          opacity: widget.opacity,
          imageProvider: AssetImage(widget.lowQualityImagePath),
        ),
      ],
    );
  }
}

/// A more advanced progressive map overlay that handles the transition between
/// low and high-quality images with a smooth fade effect.
class AdvancedProgressiveMapOverlay extends StatefulWidget {
  final String lowQualityImagePath;
  final String highQualityImagePath;
  final LatLngBounds bounds;
  final double opacity;

  const AdvancedProgressiveMapOverlay({
    Key? key,
    required this.lowQualityImagePath,
    required this.highQualityImagePath,
    required this.bounds,
    this.opacity = 1.0,
  }) : super(key: key);

  @override
  State<AdvancedProgressiveMapOverlay> createState() => _AdvancedProgressiveMapOverlayState();
}

class _AdvancedProgressiveMapOverlayState extends State<AdvancedProgressiveMapOverlay> {
  final ImageCacheService _cacheService = ImageCacheService();
  bool _isHighQualityLoaded = false;
  bool _isLowQualityLoaded = false;
  late final ImageProvider _lowQualityImageProvider;
  late final ImageProvider _highQualityImageProvider;
  bool _didInitializeImages = false;

  @override
  void initState() {
    super.initState();
    // Initialize image providers but don't precache yet
    _lowQualityImageProvider = AssetImage(widget.lowQualityImagePath);
    _highQualityImageProvider = AssetImage(widget.highQualityImagePath);
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Only run this once
    if (!_didInitializeImages) {
      _didInitializeImages = true;
      _loadImages();
    }
  }
  
  Future<void> _loadImages() async {
    try {
      debugPrint('Loading low-quality image...');
      
      // Load low-quality image first
      await _loadLowQualityImage();
      
      // Then load high-quality image
      _loadHighQualityImage();
    } catch (e) {
      debugPrint('Error in _loadImages: $e');
    }
  }
  
  Future<void> _loadLowQualityImage() async {
    try {
      // Precache the low-quality image
      await precacheImage(_lowQualityImageProvider, context);
      
      if (mounted) {
        setState(() {
          _isLowQualityLoaded = true;
        });
      }
      
      debugPrint('Low-quality image loaded successfully!');
    } catch (e) {
      debugPrint('Error loading low-quality image: $e');
    }
  }

  Future<void> _loadHighQualityImage() async {
    try {
      debugPrint('Starting to load high-quality image...');
      
      // Precache the high-quality image
      await precacheImage(_highQualityImageProvider, context);
      
      debugPrint('High-quality image loaded successfully!');
      
      if (mounted) {
        setState(() {
          _isHighQualityLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading high-quality image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building AdvancedProgressiveMapOverlay, lowQualityLoaded: $_isLowQualityLoaded, highQualityLoaded: $_isHighQualityLoaded');
    
    return Stack(
      children: [
        // Low-quality image layer
        if (_isLowQualityLoaded)
          OverlayImageLayer(
            overlayImages: [
              OverlayImage(
                bounds: widget.bounds,
                opacity: _isHighQualityLoaded ? 0.0 : widget.opacity, // Hide when high-quality is loaded
                imageProvider: _lowQualityImageProvider,
              ),
            ],
          ),
        
        // High-quality image layer with fade-in animation
        if (_isHighQualityLoaded)
          AnimatedOpacity(
            opacity: 1.0,
            duration: const Duration(milliseconds: 800),
            child: OverlayImageLayer(
              overlayImages: [
                OverlayImage(
                  bounds: widget.bounds,
                  opacity: widget.opacity,
                  imageProvider: _highQualityImageProvider,
                ),
              ],
            ),
          ),
          
        // Show loading indicator if neither image is loaded
        if (!_isLowQualityLoaded && !_isHighQualityLoaded)
          const Center(
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }
}
