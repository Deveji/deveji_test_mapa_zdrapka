import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapCalculationHelper {
  // Calculate minimum zoom level based on screen height
  static double calculateMinZoomForHeight(BuildContext context, LatLngBounds bounds) {
    final screenHeight = MediaQuery.of(context).size.height;
    final boundsHeight = bounds.north - bounds.south;
    
    // This is a simplified calculation - in a real app you might need to adjust this
    // based on the specific projection and map characteristics
    // The constant factor (0.0009) is an approximation that may need adjustment
    return (screenHeight / (boundsHeight * 111000)) * 0.0009;
  }
  
  // Calculate minimum zoom level based on screen width
  static double calculateMinZoomForWidth(BuildContext context, LatLngBounds bounds) {
    final screenWidth = MediaQuery.of(context).size.width;
    final boundsWidth = bounds.east - bounds.west;
    final latitudeFactor = math.cos(bounds.center.latitude * math.pi / 180);
    
    // Adjust for the fact that longitude degrees vary in distance based on latitude
    // The constant factor (0.0009) is an approximation that may need adjustment
    return (screenWidth / (boundsWidth * 111000 * latitudeFactor)) * 0.0009;
  }
  
  // Calculate appropriate minimum zoom level based on screen size and bounds
  static double calculateMinZoom(BuildContext context, LatLngBounds bounds) {
    // Get screen size to calculate appropriate min zoom
    final screenSize = MediaQuery.of(context).size;
    final screenAspectRatio = screenSize.width / screenSize.height;
    
    // Calculate the bounds aspect ratio
    final boundsWidth = bounds.east - bounds.west;
    final boundsHeight = bounds.north - bounds.south;
    final boundsAspectRatio = boundsWidth / boundsHeight;
    
    // Calculate minimum zoom based on screen size and bounds
    // This ensures the map always fills the viewport
    double calculatedMinZoom = 5.6; // Default min zoom
    
    // Adjust min zoom based on which dimension is limiting
    if (screenAspectRatio > boundsAspectRatio) {
      // Height is the limiting factor
      calculatedMinZoom = calculateMinZoomForHeight(context, bounds);
    } else {
      // Width is the limiting factor
      calculatedMinZoom = calculateMinZoomForWidth(context, bounds);
    }
    
    // Add a small buffer to ensure the image always fills the screen
    return calculatedMinZoom + 0.1;
  }
  
  // Calculate font size based on zoom level
  static double calculateFontSize(double baseSize, double currentZoom, double referenceZoom) {
    return baseSize * (currentZoom / referenceZoom);
  }
}
