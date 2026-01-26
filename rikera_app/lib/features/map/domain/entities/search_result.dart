import 'location.dart';
import 'search_result_type.dart';

/// Represents a single result from a place search.
///
/// Search results contain information about places, addresses, or points of
/// interest that match a user's search query.
class SearchResult {
  /// Unique identifier for this result
  final String id;

  /// Name of the place or location
  final String name;

  /// Full address of the location (optional)
  final String? address;

  /// Geographic coordinates of the result
  final Location location;

  /// Type/category of this result
  final SearchResultType type;

  /// Distance from the search origin in meters (optional)
  final double? distanceMeters;

  const SearchResult({
    required this.id,
    required this.name,
    this.address,
    required this.location,
    required this.type,
    this.distanceMeters,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SearchResult &&
        other.id == id &&
        other.name == name &&
        other.address == address &&
        other.location == location &&
        other.type == type &&
        other.distanceMeters == distanceMeters;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        address.hashCode ^
        location.hashCode ^
        type.hashCode ^
        distanceMeters.hashCode;
  }

  @override
  String toString() {
    return 'SearchResult(id: $id, name: $name, address: $address, '
        'type: $type, distance: $distanceMeters m)';
  }
}
