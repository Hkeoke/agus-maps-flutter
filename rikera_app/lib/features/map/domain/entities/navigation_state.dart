import 'location.dart';
import 'route.dart';
import 'route_segment.dart';
import 'turn_direction.dart';

/// Represents the current state of an active navigation session.
///
/// This entity tracks the user's progress along a route, including current
/// position, upcoming maneuvers, distances, and off-route status.
class NavigationState {
  /// The route being followed
  final Route route;

  /// Current location of the user
  final Location currentLocation;

  /// The current segment of the route
  final RouteSegment? currentSegment;

  /// The next segment of the route
  final RouteSegment? nextSegment;

  /// Distance to the next turn in meters
  final double distanceToNextTurnMeters;

  /// Remaining distance to destination in meters
  final double remainingDistanceMeters;

  /// Remaining time to destination in seconds
  final int remainingTimeSeconds;

  /// Whether the user is off route
  final bool isOffRoute;

  /// The current street name
  final String? currentStreetName;

  /// The next street name
  final String? nextStreetName;

  /// The turn direction for the next maneuver
  final TurnDirection? turnDirection;

  /// The speed limit in meters per second
  final double? speedLimitMetersPerSecond;

  const NavigationState({
    required this.route,
    required this.currentLocation,
    this.currentSegment,
    this.nextSegment,
    required this.distanceToNextTurnMeters,
    required this.remainingDistanceMeters,
    required this.remainingTimeSeconds,
    required this.isOffRoute,
    this.currentStreetName,
    this.nextStreetName,
    this.turnDirection,
    this.speedLimitMetersPerSecond,
  });

  /// Creates a copy of this state with updated fields
  NavigationState copyWith({
    Route? route,
    Location? currentLocation,
    RouteSegment? currentSegment,
    RouteSegment? nextSegment,
    double? distanceToNextTurnMeters,
    double? remainingDistanceMeters,
    int? remainingTimeSeconds,
    bool? isOffRoute,
    String? currentStreetName,
    String? nextStreetName,
    TurnDirection? turnDirection,
    double? speedLimitMetersPerSecond,
  }) {
    return NavigationState(
      route: route ?? this.route,
      currentLocation: currentLocation ?? this.currentLocation,
      currentSegment: currentSegment ?? this.currentSegment,
      nextSegment: nextSegment ?? this.nextSegment,
      distanceToNextTurnMeters:
          distanceToNextTurnMeters ?? this.distanceToNextTurnMeters,
      remainingDistanceMeters:
          remainingDistanceMeters ?? this.remainingDistanceMeters,
      remainingTimeSeconds: remainingTimeSeconds ?? this.remainingTimeSeconds,
      isOffRoute: isOffRoute ?? this.isOffRoute,
      currentStreetName: currentStreetName ?? this.currentStreetName,
      nextStreetName: nextStreetName ?? this.nextStreetName,
      turnDirection: turnDirection ?? this.turnDirection,
      speedLimitMetersPerSecond:
          speedLimitMetersPerSecond ?? this.speedLimitMetersPerSecond,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NavigationState &&
        other.route == route &&
        other.currentLocation == currentLocation &&
        other.currentSegment == currentSegment &&
        other.nextSegment == nextSegment &&
        other.distanceToNextTurnMeters == distanceToNextTurnMeters &&
        other.remainingDistanceMeters == remainingDistanceMeters &&
        other.remainingTimeSeconds == remainingTimeSeconds &&
        other.isOffRoute == isOffRoute &&
        other.currentStreetName == currentStreetName &&
        other.nextStreetName == nextStreetName &&
        other.turnDirection == turnDirection &&
        other.speedLimitMetersPerSecond == speedLimitMetersPerSecond;
  }

  @override
  int get hashCode {
    return route.hashCode ^
        currentLocation.hashCode ^
        currentSegment.hashCode ^
        nextSegment.hashCode ^
        distanceToNextTurnMeters.hashCode ^
        remainingDistanceMeters.hashCode ^
        remainingTimeSeconds.hashCode ^
        isOffRoute.hashCode ^
        currentStreetName.hashCode ^
        nextStreetName.hashCode ^
        turnDirection.hashCode ^
        speedLimitMetersPerSecond.hashCode;
  }

  @override
  String toString() {
    return 'NavigationState(distToTurn: $distanceToNextTurnMeters m, '
        'remaining: $remainingDistanceMeters m, time: $remainingTimeSeconds s, '
        'offRoute: $isOffRoute)';
  }
}
