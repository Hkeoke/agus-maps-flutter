import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/domain/repositories/repositories.dart';

/// Use case for tracking the user's location with permission checking.
///
/// This use case provides a stream of location updates for navigation and
/// map display, ensuring location permissions are granted before streaming.
///
/// Requirements: 4.1, 4.2
class TrackLocationUseCase {
  final LocationRepository _repository;

  const TrackLocationUseCase(this._repository);

  /// Returns a stream of location updates.
  ///
  /// The stream emits [Location] objects as the device's position changes.
  /// Updates include:
  /// - Latitude and longitude
  /// - Altitude (if available)
  /// - Accuracy
  /// - Speed and heading (if moving)
  /// - Timestamp
  ///
  /// The stream automatically handles:
  /// - Location filtering and smoothing
  /// - Error conditions (GPS unavailable, low accuracy)
  ///
  /// The stream will emit an error if:
  /// - Location permissions are not granted
  /// - Location services are unavailable
  ///
  /// Before subscribing to this stream, the caller should ensure
  /// location permissions are granted by calling [requestPermissions].
  ///
  /// Requirements: 4.1, 4.2
  Stream<Location> execute() {
    // Delegate to repository which handles:
    // - Streaming location updates
    // - Filtering and smoothing
    // - Error handling for permission and service issues
    return _repository.getLocationStream();
  }

  /// Requests location permissions from the user.
  ///
  /// Returns true if permissions are granted, false otherwise.
  ///
  /// This should be called before calling [execute] to ensure
  /// the location stream can function properly.
  ///
  /// If permissions are denied, the app should guide the user
  /// to enable them in system settings.
  ///
  /// Requirements: 4.1
  Future<bool> requestPermissions() async {
    return await _repository.requestPermissions();
  }

  /// Checks if location permissions are currently granted.
  ///
  /// Returns true if the app has permission to access location services,
  /// false otherwise.
  ///
  /// This can be used to check permission status without triggering
  /// a permission request dialog.
  ///
  /// Requirements: 4.1
  Future<bool> hasPermissions() async {
    return await _repository.hasPermissions();
  }

  /// Gets the current location as a one-time request.
  ///
  /// Returns the current [Location] if available, or null if:
  /// - Location permissions are not granted
  /// - Location services are disabled
  /// - Location cannot be determined
  ///
  /// This is useful for getting an initial position before starting
  /// the location stream.
  ///
  /// Requirements: 4.1
  Future<Location?> getCurrentLocation() async {
    return await _repository.getCurrentLocation();
  }
}
