import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Represents a cached image with metadata
class _CachedImage {
  final ui.Image image;
  final DateTime timestamp;
  final int sizeInBytes;

  _CachedImage({
    required this.image,
    required this.timestamp,
    required this.sizeInBytes,
  });
}

/// A service for caching and managing large images to improve loading performance
/// and prevent reloading during UI rerenders.
class ImageCacheService {
  // Singleton pattern
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal() {
    initCleanupTimer();
  }

  // Cache for storing loaded images with timestamps
  final Map<String, _CachedImage> _imageCache = {};
  
  // Cache configuration
  static const int _maxCacheSize = 100 * 1024 * 1024; // 100MB limit
  static const Duration _maxCacheAge = Duration(hours: 1);
  
  // Current cache size in bytes
  int _currentCacheSize = 0;
  
  // Flag to track if precaching is in progress
  bool _isPrecaching = false;

  // Timer for periodic cache cleanup
  Timer? _cleanupTimer;

  // Initialize cleanup timer
  void initCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      _performCacheCleanup();
    });
  }

  void dispose() {
    _cleanupTimer?.cancel();
    clearCache();
  }

  /// Performs periodic cache cleanup based on age and size limits
  void _performCacheCleanup() {
    final now = DateTime.now();
    
    // Remove expired entries
    _imageCache.removeWhere((key, cachedImage) {
      if (now.difference(cachedImage.timestamp) > _maxCacheAge) {
        _currentCacheSize -= cachedImage.sizeInBytes;
        return true;
      }
      return false;
    });

    // If still over size limit, remove oldest entries
    if (_currentCacheSize > _maxCacheSize) {
      final entries = _imageCache.entries.toList()
        ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));
      
      for (final entry in entries) {
        if (_currentCacheSize <= _maxCacheSize) break;
        _currentCacheSize -= entry.value.sizeInBytes;
        _imageCache.remove(entry.key);
      }
    }
  }

  /// Estimates the size of an image in bytes
  int _estimateImageSize(ui.Image image) {
    // Assuming 4 bytes per pixel (RGBA)
    return image.width * image.height * 4;
  }

  Future<void> precacheAssetImage(String assetPath) async {
    if (_imageCache.containsKey(assetPath)) {
      debugPrint('Image $assetPath already cached');
      return;
    }

    if (_isPrecaching) {
      debugPrint('Precaching already in progress for $assetPath');
      return;
    }

    _isPrecaching = true;
    debugPrint('Precaching image: $assetPath');

    try {
      // Load the asset as bytes
      debugPrint('Loading asset bytes for: $assetPath');
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();
      debugPrint('Loaded ${bytes.length} bytes for: $assetPath');
      
      // Decode the image
      debugPrint('Decoding image: $assetPath');
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      
      final image = frameInfo.image;
      final imageSize = _estimateImageSize(image);

      // Check if adding this image would exceed cache size limit
      if (_currentCacheSize + imageSize > _maxCacheSize) {
        _performCacheCleanup();
      }

      // Store the image in our cache
      _imageCache[assetPath] = _CachedImage(
        image: image,
        timestamp: DateTime.now(),
        sizeInBytes: imageSize,
      );
      _currentCacheSize += imageSize;
      
      debugPrint('Successfully cached image: $assetPath (${image.width}x${image.height})');
    } catch (e) {
      debugPrint('Error precaching image $assetPath: $e');
      rethrow;
    } finally {
      _isPrecaching = false;
    }
  }

  /// Gets a cached image. If the image is not in the cache, it will be loaded.
  /// Returns a Future that completes with the loaded image.
  Future<ui.Image> getCachedImage(String assetPath) async {
    final cachedImage = _imageCache[assetPath];
    if (cachedImage != null) {
      // Update timestamp to mark as recently used
      _imageCache[assetPath] = _CachedImage(
        image: cachedImage.image,
        timestamp: DateTime.now(),
        sizeInBytes: cachedImage.sizeInBytes,
      );
      return cachedImage.image;
    }
    
    await precacheAssetImage(assetPath);
    return _imageCache[assetPath]!.image;
  }

  /// Checks if an image is already cached.
  bool isImageCached(String assetPath) {
    if (!_imageCache.containsKey(assetPath)) return false;
    
    // Check if the cached image has expired
    final cachedImage = _imageCache[assetPath]!;
    if (DateTime.now().difference(cachedImage.timestamp) > _maxCacheAge) {
      _currentCacheSize -= cachedImage.sizeInBytes;
      _imageCache.remove(assetPath);
      return false;
    }
    
    return true;
  }

  /// Clears the image cache.
  void clearCache() {
    _imageCache.clear();
    _currentCacheSize = 0;
    debugPrint('Image cache cleared');
  }
}
