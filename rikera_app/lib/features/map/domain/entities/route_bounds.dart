/// Represents the geographic bounding box of a route.
class RouteBounds {
  /// Minimum latitude (south)
  final double minLatitude;

  /// Maximum latitude (north)
  final double maxLatitude;

  /// Minimum longitude (west)
  final double minLongitude;

  /// Maximum longitude (east)
  final double maxLongitude;

  const RouteBounds({
    required this.minLatitude,
    required this.maxLatitude,
    required this.minLongitude,
    required this.maxLongitude,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is RouteBounds &&
        other.minLatitude == minLatitude &&
        other.maxLatitude == maxLatitude &&
        other.minLongitude == minLongitude &&
        other.maxLongitude == maxLongitude;
  }

  @override
  int get hashCode {
    return minLatitude.hashCode ^
        maxLatitude.hashCode ^
        minLongitude.hashCode ^
        maxLongitude.hashCode;
  }

  @override
  String toString() {
    return 'RouteBounds(minLat: $minLatitude, maxLat: $maxLatitude, '
        'minLon: $minLongitude, maxLon: $maxLongitude)';
  }
}
