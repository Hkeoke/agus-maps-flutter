import 'package:equatable/equatable.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';

/// Base class for all map states.
abstract class MapState extends Equatable {
  const MapState();

  @override
  List<Object?> get props => [];
}

/// Initial state before map is ready.
class MapInitial extends MapState {
  const MapInitial();
}

/// Map surface is ready for interaction.
class MapReady extends MapState {
  final Location? location;
  final int zoom;
  final Route? routeOverlay;

  const MapReady({
    this.location,
    this.zoom = 12,
    this.routeOverlay,
  });

  @override
  List<Object?> get props => [location, zoom, routeOverlay];

  MapReady copyWith({
    Location? location,
    int? zoom,
    Route? routeOverlay,
    bool clearRoute = false,
  }) {
    return MapReady(
      location: location ?? this.location,
      zoom: zoom ?? this.zoom,
      routeOverlay: clearRoute ? null : (routeOverlay ?? this.routeOverlay),
    );
  }
}

/// Map download is required for the current location.
class MapDownloadRequired extends MapState {
  final String countryName;
  final Location location;

  const MapDownloadRequired({
    required this.countryName,
    required this.location,
  });

  @override
  List<Object?> get props => [countryName, location];
}

/// Map selection info is available to display.
class MapSelectionAvailable extends MapState {
  final Map<String, dynamic> selectionInfo;

  const MapSelectionAvailable(this.selectionInfo);

  @override
  List<Object?> get props => [selectionInfo];
}

/// Re-registering downloaded maps.
class MapReRegistering extends MapState {
  const MapReRegistering();
}
