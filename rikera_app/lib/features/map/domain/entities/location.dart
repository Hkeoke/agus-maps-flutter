/// Represents a geographic location with associated metadata.
///
/// This entity encapsulates GPS coordinates and movement data for tracking
/// user position during navigation.
class Location {
  /// Latitude in degrees (-90 to 90)
  final double latitude;

  /// Longitude in degrees (-180 to 180)
  final double longitude;

  /// Altitude in meters above sea level (optional)
  final double? altitude;

  /// Horizontal accuracy in meters (optional)
  final double? accuracy;

  /// Speed in meters per second (optional)
  final double? speed;

  /// Heading/bearing in degrees (0-360, where 0 is north) (optional)
  final double? heading;

  /// Timestamp when this location was recorded
  final DateTime timestamp;

  const Location({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.speed,
    this.heading,
    required this.timestamp,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Location &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.altitude == altitude &&
        other.accuracy == accuracy &&
        other.speed == speed &&
        other.heading == heading &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return latitude.hashCode ^
        longitude.hashCode ^
        altitude.hashCode ^
        accuracy.hashCode ^
        speed.hashCode ^
        heading.hashCode ^
        timestamp.hashCode;
  }

  @override
  String toString() {
    return 'Location(lat: $latitude, lon: $longitude, alt: $altitude, '
        'acc: $accuracy, speed: $speed, heading: $heading, time: $timestamp)';
  }
}
