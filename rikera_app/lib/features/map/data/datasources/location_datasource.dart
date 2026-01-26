import 'dart:async';
import 'package:geolocator/geolocator.dart';

/// Data source for location services using the geolocator package.
///
/// This data source provides GPS location tracking with permission handling
/// and error management.
class LocationDataSource {
  StreamSubscription<Position>? _positionSubscription;

  /// Get a stream of position updates.
  ///
  /// The stream emits [Position] objects as the device location changes.
  /// Location settings are optimized for navigation:
  /// - High accuracy (GPS)
  /// - Distance filter: 5 meters (reduces noise)
  /// - Time limit: 10 seconds (ensures fresh data)
  ///
  /// Throws [LocationException] if permissions are denied or location
  /// services are disabled.
  Stream<Position> getPositionStream() async* {
    // Check permissions first
    final hasPermission = await checkPermission();
    if (!hasPermission) {
      throw LocationException(
        'Location permissions not granted. '
        'Please enable location access in settings.',
      );
    }

    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException(
        'Location services are disabled. '
        'Please enable location services in device settings.',
      );
    }

    // Configure location settings for navigation
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update every 5 meters
      timeLimit: Duration(seconds: 10),
    );

    try {
      // Stream position updates
      await for (final position in Geolocator.getPositionStream(
        locationSettings: locationSettings,
      )) {
        yield position;
      }
    } catch (e) {
      throw LocationException('Failed to get position stream: $e');
    }
  }

  /// Get the current position once.
  ///
  /// This is useful for getting an initial location without starting
  /// continuous tracking.
  ///
  /// Returns null if location cannot be determined.
  /// Throws [LocationException] if permissions are denied.
  Future<Position?> getCurrentPosition() async {
    try {
      // Check permissions first
      final hasPermission = await checkPermission();
      if (!hasPermission) {
        throw LocationException(
          'Location permissions not granted. '
          'Please enable location access in settings.',
        );
      }

      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw LocationException(
          'Location services are disabled. '
          'Please enable location services in device settings.',
        );
      }

      // Get current position with high accuracy
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      return position;
    } on TimeoutException {
      // Timeout is not an error, just return null
      return null;
    } catch (e) {
      if (e is LocationException) rethrow;
      throw LocationException('Failed to get current position: $e');
    }
  }

  /// Request location permissions from the user.
  ///
  /// Returns true if permissions are granted (either already granted or
  /// newly granted by the user).
  ///
  /// Returns false if permissions are denied or permanently denied.
  Future<bool> requestPermission() async {
    try {
      // Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();

      // If denied, request permission
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // Return true if we have permission
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      throw LocationException('Failed to request permission: $e');
    }
  }

  /// Check if location permissions are granted.
  ///
  /// Returns true if permissions are granted (always or while in use).
  /// Returns false if permissions are denied or not determined.
  Future<bool> checkPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      throw LocationException('Failed to check permission: $e');
    }
  }

  /// Check if location services are enabled on the device.
  ///
  /// Returns true if GPS/location services are enabled.
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      throw LocationException('Failed to check location service status: $e');
    }
  }

  /// Open the device's location settings.
  ///
  /// This allows the user to enable location services or grant permissions.
  /// Returns true if settings were opened successfully.
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      throw LocationException('Failed to open location settings: $e');
    }
  }

  /// Open the app's settings page.
  ///
  /// This allows the user to grant location permissions if they were
  /// previously denied.
  /// Returns true if settings were opened successfully.
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      throw LocationException('Failed to open app settings: $e');
    }
  }

  /// Cancel the position stream subscription.
  ///
  /// Call this to stop receiving location updates and free resources.
  Future<void> cancelStream() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Dispose of resources.
  Future<void> dispose() async {
    await cancelStream();
  }
}

/// Exception thrown when location operations fail.
class LocationException implements Exception {
  final String message;

  LocationException(this.message);

  @override
  String toString() => 'LocationException: $message';
}
