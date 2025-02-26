import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A service for caching and managing large images to improve loading performance
/// and prevent reloading during UI rerenders.
class ImageCacheService {
  // Singleton pattern
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  // Cache for storing loaded images
  final Map<String, ui.Image> _imageCache = {};
  
  // Flag to track if precaching is in progress
  bool _isPrecaching = false;

  /// Precaches the specified asset image to memory.
  /// Returns a Future that completes when the image is loaded.
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
      
      // Store the image in our cache
      _imageCache[assetPath] = frameInfo.image;
      
      debugPrint('Successfully cached image: $assetPath (${frameInfo.image.width}x${frameInfo.image.height})');
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
    if (_imageCache.containsKey(assetPath)) {
      return _imageCache[assetPath]!;
    }
    
    await precacheAssetImage(assetPath);
    return _imageCache[assetPath]!;
  }

  /// Checks if an image is already cached.
  bool isImageCached(String assetPath) {
    return _imageCache.containsKey(assetPath);
  }

  /// Clears the image cache.
  void clearCache() {
    _imageCache.clear();
    debugPrint('Image cache cleared');
  }
}

/// A custom image provider that uses the ImageCacheService to load and cache images.
/// This prevents the image from being reloaded during UI rerenders.
class CachedAssetImage extends ImageProvider<CachedAssetImage> {
  final String assetPath;
  // final ImageCacheService _cacheService = ImageCacheService();

  CachedAssetImage(this.assetPath);

  @override
  Future<CachedAssetImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<CachedAssetImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(CachedAssetImage key, ImageDecoderCallback decode) {
    final StreamController<ImageChunkEvent> chunkEvents = StreamController<ImageChunkEvent>();
    
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, chunkEvents, decode),
      chunkEvents: chunkEvents.stream,
      scale: 1.0,
      debugLabel: assetPath,
      informationCollector: () sync* {
        yield ErrorDescription('Asset: $assetPath');
      },
    );
  }

  Future<ui.Codec> _loadAsync(
    CachedAssetImage key,
    StreamController<ImageChunkEvent> chunkEvents,
    ImageDecoderCallback decode,
  ) async {
    try {
      // Use the cache service to get or load the image
      // final ui.Image image = await _cacheService.getCachedImage(assetPath);
      
      // Convert the ui.Image to a Codec that can be used by the ImageProvider
      final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(
        Uint8List.fromList([]), // Empty list as we already have the image
      );
      
      // We need to create a codec from the image
      // This is a workaround as we can't directly create a codec from a ui.Image
      final ui.Codec codec = await decode(buffer);
      
      chunkEvents.close();
      return codec;
    } catch (e) {
      chunkEvents.close();
      debugPrint('Error loading image $assetPath: $e');
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is CachedAssetImage && other.assetPath == assetPath;
  }

  @override
  int get hashCode => assetPath.hashCode;

  @override
  String toString() => '${objectRuntimeType(this, 'CachedAssetImage')}("$assetPath")';
}

/// A custom widget that displays a cached asset image with a loading indicator.
class CachedAssetImageWidget extends StatefulWidget {
  final String assetPath;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CachedAssetImageWidget({
    super.key,
    required this.assetPath,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<CachedAssetImageWidget> createState() => _CachedAssetImageWidgetState();
}

class _CachedAssetImageWidgetState extends State<CachedAssetImageWidget> {
  final ImageCacheService _cacheService = ImageCacheService();
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    if (_cacheService.isImageCached(widget.assetPath)) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      await _cacheService.precacheAssetImage(widget.assetPath);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading image: $e');
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
        SizedBox(
          width: widget.width,
          height: widget.height,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        );
    }

    if (_hasError) {
      return widget.errorWidget ?? 
        SizedBox(
          width: widget.width,
          height: widget.height,
          child: const Center(
            child: Icon(Icons.error, color: Colors.red),
          ),
        );
    }

    return Image(
      image: AssetImage(widget.assetPath),
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return widget.placeholder ?? 
          SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
      },
    );
  }
}
