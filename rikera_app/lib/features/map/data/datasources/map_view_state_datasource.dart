import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/location.dart';

/// Data source for persisting map view state using SharedPreferences.
///
/// This data source handles saving and loading the last map location and zoom level,
/// allowing the app to restore the map view when restarted.
///
/// Requirements: 12.3
class MapViewStateDataSource {
  static const String _keyMapViewState = 'map_view_state';

  final SharedPreferences _prefs;

  MapViewStateDataSource._(this._prefs);

  /// Create and initialize the map view state data source
  static Future<MapViewStateDataSource> create() async {
    final prefs = await SharedPreferences.getInstance();
    return MapViewStateDataSource._(prefs);
  }

  /// Load the last saved map view state.
  ///
  /// Returns a MapViewState object containing the last location and zoom level,
  /// or null if no state has been saved.
  Future<MapViewState?> loadMapViewState() async {
    try {
      final json = _prefs.getString(_keyMapViewState);
      if (json == null) {
        return null;
      }

      final data = jsonDecode(json) as Map<String, dynamic>;
      return MapViewState(
        location: _locationFromJson(data['location'] as Map<String, dynamic>),
        zoom: data['zoom'] as int,
      );
    } catch (e) {
      // If parsing fails, return null (no saved state)
      return null;
    }
  }

  /// Save the current map view state.
  ///
  /// Persists the location and zoom level so they can be restored
  /// when the app is restarted.
  Future<void> saveMapViewState(MapViewState state) async {
    try {
      final json = jsonEncode({
        'location': _locationToJson(state.location),
        'zoom': state.zoom,
      });
      await _prefs.setString(_keyMapViewState, json);
    } catch (e) {
      throw MapViewStateDataSourceException(
        'Failed to save map view state: $e',
      );
    }
  }

  /// Clear the saved map view state.
  Future<void> clearMapViewState() async {
    await _prefs.remove(_keyMapViewState);
  }

  /// Serialize a Location to JSON.
  Map<String, dynamic> _locationToJson(Location location) {
    return {
      'latitude': location.latitude,
      'longitude': location.longitude,
      'altitude': location.altitude,
      'accuracy': location.accuracy,
      'speed': location.speed,
      'heading': location.heading,
      'timestamp': location.timestamp.toIso8601String(),
    };
  }

  /// Deserialize a Location from JSON.
  Location _locationFromJson(Map<String, dynamic> json) {
    return Location(
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      altitude: json['altitude'] as double?,
      accuracy: json['accuracy'] as double?,
      speed: json['speed'] as double?,
      heading: json['heading'] as double?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Represents the saved map view state.
class MapViewState {
  final Location location;
  final int zoom;

  const MapViewState({required this.location, required this.zoom});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MapViewState &&
        other.location == location &&
        other.zoom == zoom;
  }

  @override
  int get hashCode => location.hashCode ^ zoom.hashCode;
}

/// Exception thrown when map view state data source operations fail.
class MapViewStateDataSourceException implements Exception {
  final String message;

  MapViewStateDataSourceException(this.message);

  @override
  String toString() => 'MapViewStateDataSourceException: $message';
}
