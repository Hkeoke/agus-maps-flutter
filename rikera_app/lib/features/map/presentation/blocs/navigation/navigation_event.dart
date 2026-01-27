import 'package:agus_maps_flutter/agus_maps_flutter.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';

/// Base class for navigation events.
abstract class NavigationEvent {
  const NavigationEvent();
}

/// Event to start navigation with a given route.
///
/// This event initiates a navigation session, enabling location tracking,
/// screen wake lock, and voice guidance.
///
/// Requirements: 6.1
class StartNavigation extends NavigationEvent {
  final Route route;
  final AgusMapController? mapController;

  const StartNavigation(this.route, {this.mapController});
}

/// Event to update the current location during navigation.
///
/// This event is triggered by location updates from the GPS and causes
/// the navigation state to be recalculated (current segment, distances, etc.).
///
/// Requirements: 6.2, 6.4
class UpdateLocation extends NavigationEvent {
  final Location location;

  const UpdateLocation(this.location);
}

/// Event to stop the current navigation session.
///
/// This event ends navigation, disables location tracking, releases the
/// screen wake lock, and stops voice guidance.
///
/// Requirements: 6.7
class StopNavigation extends NavigationEvent {
  const StopNavigation();
}
