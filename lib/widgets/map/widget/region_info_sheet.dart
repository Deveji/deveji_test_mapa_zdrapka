import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

const double maxBottomSheetHeight = 0.5; // Max height 50% of screen
const double minBottomSheetHeight = 0.1; // Min height 10% of screen

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
  final DraggableScrollableController _controller = DraggableScrollableController();

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
            minBottomSheetHeight,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
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
      initialChildSize: minBottomSheetHeight,
      minChildSize: 0,
      shouldCloseOnMinExtent: true,
      maxChildSize: maxBottomSheetHeight,
      snap: true,
      snapSizes: const [maxBottomSheetHeight],
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
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
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 50,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                // Title and close button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${widget.hitRegions!.first.regionId}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (widget.onClose != null)
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: widget.onClose,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          iconSize: 20,
                          splashRadius: 20,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Image Placeholder
                Container(
                  height: 200,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.image,
                      size: 48,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Description
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.',
                    style: Theme.of(context).textTheme.bodyMedium,
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
