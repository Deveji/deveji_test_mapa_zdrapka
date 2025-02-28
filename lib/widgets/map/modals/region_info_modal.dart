import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../../models/region_data.dart';

/// Shows a modal bottom sheet with region information
void showRegionInfoModal(
  BuildContext context,
  String eventType,
  List<dynamic> hitRegions,
  LatLng coords,
) {
  showModalBottomSheet<void>(
    context: context,
    builder: (context) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Region Information',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            '$eventType at point: (${coords.latitude.toStringAsFixed(6)}, ${coords.longitude.toStringAsFixed(6)})',
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemBuilder: (context, index) {
                final regionData = hitRegions[index];
                return ListTile(
                  leading: index == 0
                      ? const Icon(Icons.location_on)
                      : const SizedBox.shrink(),
                  title: Text('Region: ${regionData.regionId}'),
                  subtitle: Text(regionData.subtitle),
                  dense: true,
                );
              },
              itemCount: hitRegions.length,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
