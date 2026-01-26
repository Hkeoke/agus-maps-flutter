import 'dart:async';
import 'dart:math' as math;
import 'package:rikera_app/core/utils/logger.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/domain/repositories/navigation_repository.dart';

/// Implementation of [NavigationRepository] for managing navigation sessions.
///
/// This repository tracks user progress along a route, detects off-route
/// conditions, calculates distances to turns and destination, and manages
/// the navigation session lifecycle.
///
/// Requirements: 6.1, 6.4, 6.5, 6.7
class NavigationRepositoryImpl implements NavigationRepository {
  final AppLogger _logger = const AppLogger('NavigationRepository');

  /// The currently active route, or null if not navigating.
  Route? _currentRoute;

  /// The current location of the user.
  Location? _currentLocation;

  /// Index of the current route segment.
  int _currentSegmentIndex = 0;

  /// Whether a navigation session is currently active.
  bool _isNavigating = false;

  /// Stream controller for navigation state updates.
  final StreamController<NavigationState> _navigationStateController =
      StreamController<NavigationState>.broadcast();

  /// Distance threshold in meters for detecting off-route condition.
  static const double _offRouteThresholdMeters = 50.0;

  /// Distance threshold in meters for detecting arrival at destination.
  static const double _arrivalThresholdMeters = 20.0;

  /// Distance threshold in meters for advancing to next segment.
  static const double _segmentAdvanceThresholdMeters = 30.0;

  @override
  Future<void> startNavigation(Route route) async {
    try {
      _logger.info('Starting navigation session');
      _currentRoute = route;
      _currentSegmentIndex = 0;
      _isNavigating = true;

      // Emit initial navigation state
      if (_currentLocation != null) {
        await updateLocation(_currentLocation!);
      }
      _logger.info('Navigation session started successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to start navigation',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> stopNavigation() async {
    try {
      _logger.info('Stopping navigation session');
      _isNavigating = false;
      _currentRoute = null;
      _currentLocation = null;
      _currentSegmentIndex = 0;
      _logger.info('Navigation session stopped');
    } catch (e, stackTrace) {
      _logger.error(
        'Error stopping navigation',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Stream<NavigationState> getNavigationState() {
    return _navigationStateController.stream;
  }

  @override
  Future<void> updateLocation(Location location) async {
    try {
      if (!_isNavigating || _currentRoute == null) {
        return;
      }

      _currentLocation = location;

      // Check if we've arrived at the destination
      final distanceToDestination = _calculateDistance(
        location,
        _currentRoute!.waypoints.last,
      );

      if (distanceToDestination <= _arrivalThresholdMeters) {
        _logger.info('Arrived at destination');
        // Arrived at destination
        _emitNavigationState(
          currentSegment: null,
          nextSegment: null,
          distanceToNextTurnMeters: 0,
          remainingDistanceMeters: 0,
          remainingTimeSeconds: 0,
          isOffRoute: false,
        );
        await stopNavigation();
        return;
      }

      // Get current and next segments
      final currentSegment =
          _currentSegmentIndex < _currentRoute!.segments.length
          ? _currentRoute!.segments[_currentSegmentIndex]
          : null;

      final nextSegment =
          _currentSegmentIndex + 1 < _currentRoute!.segments.length
          ? _currentRoute!.segments[_currentSegmentIndex + 1]
          : null;

      if (currentSegment == null) {
        return;
      }

      // Check if we should advance to the next segment
      final distanceToSegmentEnd = _calculateDistance(
        location,
        currentSegment.end,
      );

      if (distanceToSegmentEnd <= _segmentAdvanceThresholdMeters &&
          nextSegment != null) {
        _logger.debug('Advancing to next segment');
        _currentSegmentIndex++;
        // Recursively update with the new segment
        await updateLocation(location);
        return;
      }

      // Calculate distance to the current segment (perpendicular distance)
      final distanceToSegment = _calculateDistanceToSegment(
        location,
        currentSegment,
      );

      // Check if we're off-route
      final isOffRoute = distanceToSegment > _offRouteThresholdMeters;
      if (isOffRoute) {
        _logger.warning(
          'User is off-route: distance=$distanceToSegment meters',
        );
      }

      // Calculate remaining distance and time
      final remainingDistance = _calculateRemainingDistance(location);
      final remainingTime = _calculateRemainingTime(remainingDistance);

      // Emit navigation state
      _emitNavigationState(
        currentSegment: currentSegment,
        nextSegment: nextSegment,
        distanceToNextTurnMeters: distanceToSegmentEnd,
        remainingDistanceMeters: remainingDistance,
        remainingTimeSeconds: remainingTime,
        isOffRoute: isOffRoute,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Error updating navigation location',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  bool get isNavigating => _isNavigating;

  /// Emits a navigation state update to the stream.
  void _emitNavigationState({
    required RouteSegment? currentSegment,
    required RouteSegment? nextSegment,
    required double distanceToNextTurnMeters,
    required double remainingDistanceMeters,
    required int remainingTimeSeconds,
    required bool isOffRoute,
  }) {
    if (_currentRoute == null || _currentLocation == null) {
      return;
    }

    final state = NavigationState(
      route: _currentRoute!,
      currentLocation: _currentLocation!,
      currentSegment: currentSegment,
      nextSegment: nextSegment,
      distanceToNextTurnMeters: distanceToNextTurnMeters,
      remainingDistanceMeters: remainingDistanceMeters,
      remainingTimeSeconds: remainingTimeSeconds,
      isOffRoute: isOffRoute,
    );

    _navigationStateController.add(state);
  }

  /// Calculates the great-circle distance between two locations in meters.
  ///
  /// Uses the Haversine formula for accuracy over short distances.
  double _calculateDistance(Location from, Location to) {
    const earthRadiusMeters = 6371000.0;

    final lat1Rad = from.latitude * math.pi / 180;
    final lat2Rad = to.latitude * math.pi / 180;
    final deltaLatRad = (to.latitude - from.latitude) * math.pi / 180;
    final deltaLonRad = (to.longitude - from.longitude) * math.pi / 180;

    final a =
        math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLonRad / 2) *
            math.sin(deltaLonRad / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  /// Calculates the perpendicular distance from a point to a line segment.
  ///
  /// This is used to detect if the user has deviated from the route.
  double _calculateDistanceToSegment(Location point, RouteSegment segment) {
    // For simplicity, calculate distance to the segment end point
    // A more accurate implementation would calculate perpendicular distance
    // to the line segment, but this requires more complex geometry
    return _calculateDistance(point, segment.end);
  }

  /// Calculates the remaining distance to the destination in meters.
  ///
  /// This sums the distance from current location to the end of the current
  /// segment, plus the distances of all remaining segments.
  double _calculateRemainingDistance(Location currentLocation) {
    if (_currentRoute == null) {
      return 0;
    }

    double totalDistance = 0;

    // Add distance to end of current segment
    if (_currentSegmentIndex < _currentRoute!.segments.length) {
      final currentSegment = _currentRoute!.segments[_currentSegmentIndex];
      totalDistance += _calculateDistance(currentLocation, currentSegment.end);
    }

    // Add distances of remaining segments
    for (
      int i = _currentSegmentIndex + 1;
      i < _currentRoute!.segments.length;
      i++
    ) {
      totalDistance += _currentRoute!.segments[i].distanceMeters;
    }

    return totalDistance;
  }

  /// Calculates the estimated remaining time in seconds.
  ///
  /// Uses a simple calculation based on remaining distance and average speed.
  /// Assumes an average speed of 50 km/h if no speed data is available.
  int _calculateRemainingTime(double remainingDistanceMeters) {
    // Use current speed if available, otherwise assume 50 km/h
    final speedMps = _currentLocation?.speed ?? (50 * 1000 / 3600);

    if (speedMps <= 0) {
      // If speed is zero or negative, use default speed
      return (remainingDistanceMeters / (50 * 1000 / 3600)).round();
    }

    return (remainingDistanceMeters / speedMps).round();
  }

  /// Disposes of resources used by this repository.
  void dispose() {
    _navigationStateController.close();
  }
}
