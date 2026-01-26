import 'package:rikera_app/features/map/domain/entities/entities.dart';

/// Represents the state of the map display.
///
/// This state tracks the current map view including location, zoom level,
/// and any route overlay being displayed.
class MapState {
  /// Current center location of the map view
  final Location? location;

  /// Current zoom level (higher = more zoomed in)
  final int zoom;

  /// Route to display as an overlay (optional)
  final Route? routeOverlay;

  const MapState({this.location, required this.zoom, this.routeOverlay});

  /// Initial state with default values
  factory MapState.initial() {
    return const MapState(
      location: null,
      zoom: 12, // Default zoom level
      routeOverlay: null,
    );
  }

  /// Creates a copy of this state with updated fields
  MapState copyWith({
    Location? location,
    int? zoom,
    Route? routeOverlay,
    bool clearRoute = false,
  }) {
    return MapState(
      location: location ?? this.location,
      zoom: zoom ?? this.zoom,
      routeOverlay: clearRoute ? null : (routeOverlay ?? this.routeOverlay),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MapState &&
        other.location == location &&
        other.zoom == zoom &&
        other.routeOverlay == routeOverlay;
  }

  @override
  int get hashCode {
    return location.hashCode ^ zoom.hashCode ^ routeOverlay.hashCode;
  }

  @override
  String toString() {
    return 'MapState(location: $location, zoom: $zoom, hasRoute: ${routeOverlay != null})';
  }
}
