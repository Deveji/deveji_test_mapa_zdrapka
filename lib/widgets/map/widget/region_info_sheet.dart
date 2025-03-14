import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../services/region_manager.dart';

const double maxBottomSheetHeight = 1; // Max height 50% of screen
const double minBottomSheetHeight = 0.1; // Min height 10% of screen
const double defaultBottomSheetHeight = 0.35; // Default height 35% of screen

class RegionInfoBottomSheet extends StatefulWidget {
  final String? eventType;
  final List<dynamic>? hitRegions;
  final LatLng? coords;
  final VoidCallback? onClose;

  const RegionInfoBottomSheet({
    super.key,
    this.eventType,
    this.hitRegions,
    this.coords,
    this.onClose,
  });

  @override
  State<RegionInfoBottomSheet> createState() => _RegionInfoBottomSheetState();
}

class _RegionInfoBottomSheetState extends State<RegionInfoBottomSheet> {
  final DraggableScrollableController _controller =
      DraggableScrollableController();
  ScrollController? _scrollController;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (_controller.isAttached && _controller.size == 0) {
        widget.onClose?.call();
      }
    });
  }

  @override
  void didUpdateWidget(RegionInfoBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset sheet to initial size when new regions are selected
    if (widget.hitRegions != oldWidget.hitRegions) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.isAttached) {
          _controller.animateTo(
            defaultBottomSheetHeight,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
        // Scroll to top when new region is selected
        _scrollController?.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hitRegions == null || widget.coords == null) {
      return const SizedBox.shrink();
    }

    return DraggableScrollableSheet(
      controller: _controller,
      initialChildSize: defaultBottomSheetHeight,
      minChildSize: 0,
      shouldCloseOnMinExtent: true,
      maxChildSize: maxBottomSheetHeight,
      snap: true,
      snapSizes: const [defaultBottomSheetHeight, maxBottomSheetHeight],
      builder: (BuildContext context, ScrollController scrollController) {
        _scrollController = scrollController;
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 15,
                spreadRadius: 1,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // Title and close button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${widget.hitRegions!.first.regionId}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.onClose != null)
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: widget.onClose,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              iconSize: 22,
                              splashRadius: 24,
                              style: IconButton.styleFrom(
                                foregroundColor: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Builder(
                          builder: (context) {
                            final regionManager = RegionManager();
                            final regionId = widget.hitRegions!.first.regionId;
                            final region = regionManager.regions.firstWhere(
                              (r) => r.regionId == regionId,
                            );

                            return ElevatedButton.icon(
                              onPressed:
                                  region.isScratched
                                      ? null
                                      : () {
                                        // Use the async scratch method
                                        regionManager.scratchRegion(regionId).then((
                                          _,
                                        ) {
                                          // Update this widget's state after scratching
                                          if (mounted) {
                                            setState(() {});
                                          }
                                        });
                                      },
                              icon: Icon(
                                region.isScratched
                                    ? Icons.check
                                    : Icons.brush_outlined,
                                size: 20,
                                color: Colors.white,
                              ),
                              label: Text(
                                region.isScratched
                                    ? 'Region Zdrapany'
                                    : 'Zdrap Region',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor:
                                    region.isScratched
                                        ? Colors.green[400]
                                        : Theme.of(context).primaryColor,
                                disabledForegroundColor: Colors.white70,
                                disabledBackgroundColor: Colors.green[400],
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Region Image
                Container(
                  height: 200,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    'https://picsum.photos/800/400?t=${DateTime.now().millisecondsSinceEpoch}',
                    key: ValueKey('region-${widget.hitRegions!.first.regionId}'),
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(
                            Icons.image_outlined,
                            size: 48,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Failed to load image',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                // Region Details
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About this Region',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
