import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:rikera_app/core/utils/logger.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/domain/repositories/location_repository.dart';
import 'package:rikera_app/features/map/data/datasources/location_datasource.dart';

/// Implementation of [LocationRepository] using the geolocator package.
///
/// This repository wraps the LocationDataSource to provide location tracking
/// with filtering, smoothing, and permission handling.
///
/// Requirements: 4.1, 4.2, 4.3
class LocationRepositoryImpl implements LocationRepository {
  final LocationDataSource _locationDataSource;
  final AppLogger _logger = const AppLogger('LocationRepository');

  /// Stream controller for filtered location updates.
  StreamController<Location>? _locationStreamController;

  /// Subscription to the raw location stream from the data source.
  StreamSubscription<Position>? _locationSubscription;

  /// The last emitted location, used for filtering.
  Location? _lastEmittedLocation;

  /// Minimum time between location updates in milliseconds.
  static const int _minUpdateIntervalMs = 1000;

  /// Minimum distance between location updates in meters.
  static const double _minUpdateDistanceMeters = 5.0;

  LocationRepositoryImpl({required LocationDataSource locationDataSource})
    : _locationDataSource = locationDataSource;

  @override
  Stream<Location> getLocationStream() {
    // Create a new stream controller if not already created
    _locationStreamController ??= StreamController<Location>.broadcast(
      onListen: _startLocationUpdates,
      onCancel: _stopLocationUpdates,
    );

    return _locationStreamController!.stream;
  }

  @override
  Future<Location?> getCurrentLocation() async {
    try {
      _logger.debug('Getting current location');
      final position = await _locationDataSource.getCurrentPosition();
      if (position == null) {
        _logger.warning('Current location is null');
        return null;
      }
      _logger.debug(
        'Current location obtained: ${position.latitude}, ${position.longitude}',
      );
      return _positionToLocation(position);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get current location',
        error: e,
        stackTrace: stackTrace,
      );
      // Return null if location cannot be obtained
      return null;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      _logger.info('Requesting location permissions');
      final granted = await _locationDataSource.requestPermission();
      _logger.info('Location permissions ${granted ? 'granted' : 'denied'}');
      return granted;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to request location permissions',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  @override
  Future<bool> hasPermissions() async {
    try {
      return await _locationDataSource.checkPermission();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to check location permissions',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Starts listening to location updates from the data source.
  void _startLocationUpdates() {
    try {
      _logger.info('Starting location updates');
      _locationSubscription = _locationDataSource.getPositionStream().listen(
        _handleLocationUpdate,
        onError: (error, stackTrace) {
          _logger.error(
            'Error in location stream',
            error: error,
            stackTrace: stackTrace,
          );
        },
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to start location updates',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Stops listening to location updates.
  void _stopLocationUpdates() {
    try {
      _logger.info('Stopping location updates');
      _locationSubscription?.cancel();
      _locationSubscription = null;
    } catch (e, stackTrace) {
      _logger.error(
        'Error stopping location updates',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Handles a location update from the data source.
  ///
  /// Applies filtering and smoothing before emitting to the stream:
  /// - Filters out updates that are too frequent (< 1 second)
  /// - Filters out updates that are too close (< 5 meters)
  /// - Smooths location data to reduce GPS jitter
  void _handleLocationUpdate(Position position) {
    final location = _positionToLocation(position);

    // Apply filtering
    if (_shouldFilterLocation(location)) {
      return;
    }

    // Apply smoothing (simple moving average for now)
    final smoothedLocation = _smoothLocation(location);

    // Emit the filtered and smoothed location
    _locationStreamController?.add(smoothedLocation);
    _lastEmittedLocation = smoothedLocation;
  }

  /// Converts a geolocator Position to a domain Location entity.
  Location _positionToLocation(Position position) {
    return Location(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      accuracy: position.accuracy,
      speed: position.speed,
      heading: position.heading,
      timestamp: position.timestamp,
    );
  }

  /// Determines if a location update should be filtered out.
  ///
  /// Returns true if the location should be filtered (not emitted).
  bool _shouldFilterLocation(Location location) {
    if (_lastEmittedLocation == null) {
      return false; // Always emit the first location
    }

    // Filter by time: require at least 1 second between updates
    final timeDiff = location.timestamp.difference(
      _lastEmittedLocation!.timestamp,
    );
    if (timeDiff.inMilliseconds < _minUpdateIntervalMs) {
      return true;
    }

    // Filter by distance: require at least 5 meters of movement
    final distance = _calculateDistance(_lastEmittedLocation!, location);
    if (distance < _minUpdateDistanceMeters) {
      return true;
    }

    return false;
  }

  /// Applies smoothing to a location update.
  ///
  /// Uses a simple exponential moving average to reduce GPS jitter.
  /// The smoothing factor (alpha) determines how much weight to give
  /// to the new location vs. the previous location.
  Location _smoothLocation(Location location) {
    if (_lastEmittedLocation == null) {
      return location; // No smoothing for the first location
    }

    // Smoothing factor: 0.3 means 30% new location, 70% previous location
    const alpha = 0.3;

    final smoothedLat =
        alpha * location.latitude +
        (1 - alpha) * _lastEmittedLocation!.latitude;
    final smoothedLon =
        alpha * location.longitude +
        (1 - alpha) * _lastEmittedLocation!.longitude;

    // Don't smooth altitude, accuracy, speed, or heading
    // as these can change rapidly and smoothing may hide important changes
    return Location(
      latitude: smoothedLat,
      longitude: smoothedLon,
      altitude: location.altitude,
      accuracy: location.accuracy,
      speed: location.speed,
      heading: location.heading,
      timestamp: location.timestamp,
    );
  }

  /// Calculates the distance between two locations in meters.
  ///
  /// Uses a simple Euclidean approximation for short distances.
  /// This is faster than the Haversine formula and sufficient for
  /// filtering purposes.
  double _calculateDistance(Location from, Location to) {
    const metersPerDegree = 111320.0; // Approximate at equator

    final latDiff = (to.latitude - from.latitude) * metersPerDegree;
    final lonDiff =
        (to.longitude - from.longitude) *
        metersPerDegree *
        0.5; // Rough correction for longitude

    return (latDiff * latDiff + lonDiff * lonDiff).abs();
  }

  /// Disposes of resources used by this repository.
  void dispose() {
    _stopLocationUpdates();
    _locationStreamController?.close();
    _locationStreamController = null;
  }
}
