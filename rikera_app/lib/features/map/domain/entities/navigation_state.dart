import 'location.dart';
import 'route.dart';
import 'route_segment.dart';

/// Represents the current state of an active navigation session.
///
/// This entity tracks the user's progress along a route, including current
/// position, upcoming maneuvers, distances, and off-route status.
class NavigationState {
  /// The route being followed
  final Route route;

  /// Current location of the user
  final Location currentLocation;

  /// Current route segment the user is on (optional)
  final RouteSegment? currentSegment;

  /// Next route segment after the current one (optional)
  final RouteSegment? nextSegment;

  /// Distance to the next turn in meters
  final double distanceToNextTurnMeters;

  /// Remaining distance to destination in meters
  final double remainingDistanceMeters;

  /// Remaining time to destination in seconds
  final int remainingTimeSeconds;

  /// Whether the user has deviated from the route
  final bool isOffRoute;

  const NavigationState({
    required this.route,
    required this.currentLocation,
    this.currentSegment,
    this.nextSegment,
    required this.distanceToNextTurnMeters,
    required this.remainingDistanceMeters,
    required this.remainingTimeSeconds,
    required this.isOffRoute,
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
        other.isOffRoute == isOffRoute;
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
        isOffRoute.hashCode;
  }

  @override
  String toString() {
    return 'NavigationState(distToTurn: $distanceToNextTurnMeters m, '
        'remaining: $remainingDistanceMeters m, time: $remainingTimeSeconds s, '
        'offRoute: $isOffRoute)';
  }
}
