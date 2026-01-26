import 'package:rikera_app/features/map/domain/entities/entities.dart';

/// Base class for location events.
abstract class LocationEvent {
  const LocationEvent();
}

/// Event to start tracking the user's location.
///
/// This event initiates location tracking, requesting permissions if needed.
///
/// Requirements: 4.1
class StartTracking extends LocationEvent {
  const StartTracking();
}

/// Event to stop tracking the user's location.
///
/// This event stops the location stream and releases resources.
class StopTracking extends LocationEvent {
  const StopTracking();
}

/// Event to update the current location in the location bloc.
///
/// This event is triggered internally when a new location is received
/// from the location stream.
///
/// Requirements: 4.2
class LocationUpdated extends LocationEvent {
  final Location location;

  const LocationUpdated(this.location);
}

/// Event to request location permissions.
///
/// This event triggers a permission request dialog.
///
/// Requirements: 4.1
class RequestPermissions extends LocationEvent {
  const RequestPermissions();
}
