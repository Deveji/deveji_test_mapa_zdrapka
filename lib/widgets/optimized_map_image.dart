import 'package:flutter/material.dart';
import '../services/image_cache_service.dart';
import 'package:flutter_map/flutter_map.dart';

/// A specialized widget for displaying large map images with optimized loading and caching.
/// This widget is designed to prevent the image from disappearing during UI rerenders.
class OptimizedMapImage extends StatefulWidget {
  final String assetPath;
  final LatLngBounds bounds;
  final double opacity;
  final Widget? placeholder;

  const OptimizedMapImage({
    super.key,
    required this.assetPath,
    required this.bounds,
    this.opacity = 1.0,
    this.placeholder,
  });

  @override
  State<OptimizedMapImage> createState() => _OptimizedMapImageState();
}

class _OptimizedMapImageState extends State<OptimizedMapImage> {
  final ImageCacheService _cacheService = ImageCacheService();
  bool _isLoading = true;
  bool _hasError = false;
  late ImageProvider _imageProvider;

  @override
  void initState() {
    super.initState();
    _precacheImage();
  }

  Future<void> _precacheImage() async {
    try {
      // Start precaching the image
      await _cacheService.precacheAssetImage(widget.assetPath);
      
      // Create a memory-efficient image provider
      _imageProvider = AssetImage(widget.assetPath);
      
      // Precache the image in Flutter's image cache to prevent it from being garbage collected
      // mount it first
      if (mounted) {
      await precacheImage(_imageProvider, context);
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error precaching map image: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.placeholder ?? 
        const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading map image...'),
            ],
          ),
        );
    }

    if (_hasError) {
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
                  _isLoading = true;
                  _hasError = false;
                });
                _precacheImage();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Use OverlayImage with the cached image provider
    return OverlayImage(
      bounds: widget.bounds,
      opacity: widget.opacity,
      imageProvider: _imageProvider,
    );
  }
}

/// A widget that manages the loading and display of a map with an optimized overlay image.
/// This widget handles the initial loading state and provides a smooth transition
/// when the image is ready.
class OptimizedMapOverlay extends StatefulWidget {
  final String imagePath;
  final LatLngBounds bounds;
  final double opacity;

  const OptimizedMapOverlay({
    super.key,
    required this.imagePath,
    required this.bounds,
    this.opacity = 1.0,
  });

  @override
  State<OptimizedMapOverlay> createState() => _OptimizedMapOverlayState();
}

class _OptimizedMapOverlayState extends State<OptimizedMapOverlay> {
  final ImageCacheService _cacheService = ImageCacheService();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeImage();
  }

  Future<void> _initializeImage() async {
    try {
      // Start the precaching process in the background
      _cacheService.precacheAssetImage(widget.imagePath).then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      });
    } catch (e) {
      debugPrint('Error initializing map image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return OverlayImageLayer(
      overlayImages: [
        OverlayImage(
          bounds: widget.bounds,
          opacity: widget.opacity,
          imageProvider: _isInitialized 
            ? AssetImage(widget.imagePath)
            : const AssetImage('assets/images/poland.webp'), // Use the same image but it will be cached
        ),
      ],
    );
  }
}
