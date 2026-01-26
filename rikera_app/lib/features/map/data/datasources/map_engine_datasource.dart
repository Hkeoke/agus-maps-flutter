import 'package:agus_maps_flutter/agus_maps_flutter.dart' as agus;

/// Data source wrapping agus_maps_flutter APIs for map engine operations.
///
/// This data source provides a clean interface to the CoMaps rendering engine,
/// handling initialization, map registration, and view control.
class MapEngineDataSource {
  /// Initialize the CoMaps engine with storage paths.
  ///
  /// [storagePath] is the writable directory for map data and cache.
  /// This should be called once during app initialization.
  ///
  /// Throws [MapEngineException] if initialization fails.
  Future<void> initializeEngine(String storagePath) async {
    try {
      // Extract data files (classificator, types, categories, etc.)
      final resourcePath = await agus.extractDataFiles();

      // Initialize CoMaps with separate resource and writable paths
      agus.initWithPaths(resourcePath, storagePath);
    } catch (e) {
      throw MapEngineException('Failed to initialize map engine: $e');
    }
  }

  /// Register a map file with the CoMaps engine.
  ///
  /// [filePath] is the full path to the MWM file.
  /// [version] is the snapshot version (e.g., 251209 for YYMMDD format).
  ///
  /// Returns true if registration was successful.
  /// Throws [MapEngineException] if registration fails.
  Future<bool> registerMap(String filePath, int version) async {
    try {
      final result = agus.registerSingleMapWithVersion(filePath, version);

      if (result == 0) {
        // Success - invalidate and force redraw to load tiles
        agus.invalidateMap();
        agus.forceRedraw();
        return true;
      } else if (result == -1) {
        throw MapEngineException(
          'Framework not initialized. Call after map surface is created.',
        );
      } else if (result == -2) {
        throw MapEngineException('Exception during map registration');
      } else {
        throw MapEngineException('Map registration failed with code: $result');
      }
    } catch (e) {
      if (e is MapEngineException) rethrow;
      throw MapEngineException('Failed to register map: $e');
    }
  }

  /// Set the map view to a specific location and zoom level.
  ///
  /// [lat] and [lon] are WGS84 coordinates.
  /// [zoom] is the zoom level (typically 0-20, higher is more zoomed in).
  void setMapView(double lat, double lon, int zoom) {
    try {
      agus.setView(lat, lon, zoom);
    } catch (e) {
      throw MapEngineException('Failed to set map view: $e');
    }
  }

  /// Invalidate the current viewport to force tile reload.
  ///
  /// Call this after registering maps to ensure tiles are refreshed.
  void invalidateMap() {
    agus.invalidateMap();
  }

  /// Force a complete redraw by updating the map style.
  ///
  /// This clears all render groups and forces the BackendRenderer to
  /// re-request all tiles from scratch. Use this after registering map
  /// files to ensure tiles are loaded for newly registered regions.
  void forceRedraw() {
    agus.forceRedraw();
  }

  /// Debug: List all registered MWMs and their bounds.
  ///
  /// Output goes to platform logs (Android logcat, iOS console).
  void debugListMwms() {
    agus.debugListMwms();
  }

  /// Debug: Check if a lat/lon point is covered by any registered MWM.
  ///
  /// Output goes to platform logs.
  void debugCheckPoint(double lat, double lon) {
    agus.debugCheckPoint(lat, lon);
  }
}

/// Exception thrown when map engine operations fail.
class MapEngineException implements Exception {
  final String message;

  MapEngineException(this.message);

  @override
  String toString() => 'MapEngineException: $message';
}
