import 'package:rikera_app/features/map/domain/entities/entities.dart';

/// Base class for location states.
abstract class LocationState {
  const LocationState();
}

/// Initial state before location tracking has started.
class LocationIdle extends LocationState {
  const LocationIdle();

  @override
  bool operator ==(Object other) => other is LocationIdle;

  @override
  int get hashCode => 0;
}

/// State when location tracking is active.
///
/// This state contains the current location and is updated as new
/// location data is received.
///
/// Requirements: 4.2
class LocationTracking extends LocationState {
  final Location location;

  const LocationTracking(this.location);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationTracking && other.location == location;
  }

  @override
  int get hashCode => location.hashCode;

  @override
  String toString() => 'LocationTracking($location)';
}

/// State when location permissions are denied.
///
/// This state indicates that the user has denied location permissions
/// and the app cannot track location.
///
/// Requirements: 13.2
class LocationPermissionDenied extends LocationState {
  final String message;

  const LocationPermissionDenied({
    this.message =
        'Location permission denied. Please enable location access in settings.',
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationPermissionDenied && other.message == message;
  }

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'LocationPermissionDenied($message)';
}

/// State when location tracking encounters an error.
class LocationError extends LocationState {
  final String message;

  const LocationError(this.message);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationError && other.message == message;
  }

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'LocationError($message)';
}

/// State when requesting location permissions.
class LocationRequestingPermission extends LocationState {
  const LocationRequestingPermission();

  @override
  bool operator ==(Object other) => other is LocationRequestingPermission;

  @override
  int get hashCode => 1;
}
