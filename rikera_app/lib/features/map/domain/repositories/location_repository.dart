import 'package:rikera_app/features/map/domain/entities/entities.dart';

/// Repository interface for location tracking and permissions.
///
/// This repository provides access to the device's GPS location services,
/// handles location permissions, and streams location updates for navigation.
///
/// Requirements: 4.1, 4.2
abstract class LocationRepository {
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
  /// - Permission checks
  ///
  /// The stream will emit an error if location permissions are denied
  /// or if location services are unavailable.
  ///
  /// Requirements: 4.1, 4.2
  Stream<Location> getLocationStream();

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
  Future<Location?> getCurrentLocation();

  /// Requests location permissions from the user.
  ///
  /// Returns true if permissions are granted, false otherwise.
  ///
  /// This should be called before attempting to access location services.
  /// If permissions are denied, the app should guide the user to enable
  /// them in system settings.
  ///
  /// Requirements: 4.1
  Future<bool> requestPermissions();

  /// Checks if location permissions are currently granted.
  ///
  /// Returns true if the app has permission to access location services,
  /// false otherwise.
  ///
  /// This can be used to check permission status without triggering
  /// a permission request dialog.
  ///
  /// Requirements: 4.1
  Future<bool> hasPermissions();
}
