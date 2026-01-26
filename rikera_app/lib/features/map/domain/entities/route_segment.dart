import 'location.dart';
import 'turn_direction.dart';

/// Represents a single segment of a route for turn-by-turn navigation.
///
/// Each segment corresponds to a portion of the route between two maneuvers,
/// containing information about the turn, distance, street name, and speed limit.
class RouteSegment {
  /// Starting location of this segment
  final Location start;

  /// Ending location of this segment
  final Location end;

  /// Direction of the turn at the end of this segment
  final TurnDirection turnDirection;

  /// Distance of this segment in meters
  final double distanceMeters;

  /// Name of the street for this segment (optional)
  final String? streetName;

  /// Speed limit for this segment in km/h (optional)
  final int? speedLimitKmh;

  const RouteSegment({
    required this.start,
    required this.end,
    required this.turnDirection,
    required this.distanceMeters,
    this.streetName,
    this.speedLimitKmh,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is RouteSegment &&
        other.start == start &&
        other.end == end &&
        other.turnDirection == turnDirection &&
        other.distanceMeters == distanceMeters &&
        other.streetName == streetName &&
        other.speedLimitKmh == speedLimitKmh;
  }

  @override
  int get hashCode {
    return start.hashCode ^
        end.hashCode ^
        turnDirection.hashCode ^
        distanceMeters.hashCode ^
        streetName.hashCode ^
        speedLimitKmh.hashCode;
  }

  @override
  String toString() {
    return 'RouteSegment(turn: $turnDirection, distance: $distanceMeters m, '
        'street: $streetName, speedLimit: $speedLimitKmh km/h)';
  }
}
