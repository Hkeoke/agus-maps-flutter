import 'bookmark_category.dart';
import 'location.dart';

/// Represents a saved bookmark location.
///
/// Bookmarks allow users to save frequently visited locations for quick access.
class Bookmark {
  /// Unique identifier for this bookmark
  final String id;

  /// User-defined name for the bookmark
  final String name;

  /// Geographic location of the bookmark
  final Location location;

  /// Category of the bookmark (home, work, favorite, etc.)
  final BookmarkCategory category;

  /// Timestamp when the bookmark was created
  final DateTime createdAt;

  /// Timestamp when the bookmark was last used (optional)
  final DateTime? lastUsedAt;

  const Bookmark({
    required this.id,
    required this.name,
    required this.location,
    required this.category,
    required this.createdAt,
    this.lastUsedAt,
  });

  /// Creates a copy of this bookmark with updated fields
  Bookmark copyWith({
    String? id,
    String? name,
    Location? location,
    BookmarkCategory? category,
    DateTime? createdAt,
    DateTime? lastUsedAt,
  }) {
    return Bookmark(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Bookmark &&
        other.id == id &&
        other.name == name &&
        other.location == location &&
        other.category == category &&
        other.createdAt == createdAt &&
        other.lastUsedAt == lastUsedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        location.hashCode ^
        category.hashCode ^
        createdAt.hashCode ^
        lastUsedAt.hashCode;
  }

  @override
  String toString() {
    return 'Bookmark(id: $id, name: $name, category: $category, '
        'created: $createdAt, lastUsed: $lastUsedAt)';
  }
}
