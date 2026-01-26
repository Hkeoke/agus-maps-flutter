import 'package:agus_maps_flutter/agus_maps_flutter.dart' as agus;
import 'package:flutter/material.dart';

/// Manages map style synchronization with app theme
class MapStyleManager {
  /// Set map style based on Flutter theme brightness
  ///
  /// For car navigation, uses vehicle-optimized styles:
  /// - Light theme -> VehicleLight style
  /// - Dark theme -> VehicleDark style
  static void syncWithTheme(Brightness brightness) {
    final mapStyle = brightness == Brightness.light
        ? agus.MapStyle.vehicleLight
        : agus.MapStyle.vehicleDark;

    try {
      agus.setMapStyle(mapStyle);
      debugPrint('[MapStyleManager] Map style set to: ${mapStyle.name}');
    } catch (e) {
      debugPrint('[MapStyleManager] Error setting map style: $e');
    }
  }

  /// Get the current map style
  static agus.MapStyle getCurrentStyle() {
    try {
      return agus.getMapStyle();
    } catch (e) {
      debugPrint('[MapStyleManager] Error getting map style: $e');
      return agus.MapStyle.vehicleLight;
    }
  }

  /// Check if current style is dark
  static bool isDarkStyle() {
    final style = getCurrentStyle();
    return style == agus.MapStyle.defaultDark ||
        style == agus.MapStyle.vehicleDark ||
        style == agus.MapStyle.outdoorsDark;
  }
}
