import 'location.dart';
import 'route_bounds.dart';
import 'route_segment.dart';

/// Represents a calculated navigation route from origin to destination.
///
/// A route contains the complete path with waypoints, segments for turn-by-turn
/// navigation, and metadata like total distance and estimated time.
class Route {
  /// List of waypoints defining the route path
  final List<Location> waypoints;

  /// Total distance of the route in meters
  final double totalDistanceMeters;

  /// Estimated time to complete the route in seconds
  final int estimatedTimeSeconds;

  /// List of route segments for turn-by-turn navigation
  final List<RouteSegment> segments;

  /// Geographic bounding box containing the entire route
  final RouteBounds bounds;

  const Route({
    required this.waypoints,
    required this.totalDistanceMeters,
    required this.estimatedTimeSeconds,
    required this.segments,
    required this.bounds,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Route &&
        _listEquals(other.waypoints, waypoints) &&
        other.totalDistanceMeters == totalDistanceMeters &&
        other.estimatedTimeSeconds == estimatedTimeSeconds &&
        _listEquals(other.segments, segments) &&
        other.bounds == bounds;
  }

  @override
  int get hashCode {
    return waypoints.hashCode ^
        totalDistanceMeters.hashCode ^
        estimatedTimeSeconds.hashCode ^
        segments.hashCode ^
        bounds.hashCode;
  }

  @override
  String toString() {
    return 'Route(waypoints: ${waypoints.length}, distance: $totalDistanceMeters m, '
        'time: $estimatedTimeSeconds s, segments: ${segments.length})';
  }

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
