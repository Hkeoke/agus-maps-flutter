import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/entities/bookmark_category.dart';
import '../../domain/entities/location.dart';

/// Data source for bookmark persistence using shared_preferences.
///
/// This data source handles serialization/deserialization of bookmarks
/// to JSON and stores them in shared preferences.
class BookmarkDataSource {
  static const String _key = 'bookmarks';

  final SharedPreferences _prefs;
  List<Bookmark> _cache = [];

  BookmarkDataSource._(this._prefs);

  /// Create and initialize the bookmark data source.
  ///
  /// This is an async factory method that creates the SharedPreferences
  /// instance and loads existing bookmarks.
  static Future<BookmarkDataSource> create() async {
    final prefs = await SharedPreferences.getInstance();
    final dataSource = BookmarkDataSource._(prefs);
    await dataSource._load();
    return dataSource;
  }

  /// Load bookmarks from shared preferences.
  Future<void> _load() async {
    try {
      final json = _prefs.getString(_key);
      if (json != null) {
        final list = jsonDecode(json) as List;
        _cache = list
            .map((e) => _bookmarkFromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // If parsing fails, start with empty list
      _cache = [];
      throw BookmarkDataSourceException('Failed to load bookmarks: $e');
    }
  }

  /// Save bookmarks to shared preferences.
  Future<void> _save() async {
    try {
      final json = jsonEncode(_cache.map((e) => _bookmarkToJson(e)).toList());
      await _prefs.setString(_key, json);
    } catch (e) {
      throw BookmarkDataSourceException('Failed to save bookmarks: $e');
    }
  }

  /// Get all bookmarks.
  ///
  /// Returns an unmodifiable list of all stored bookmarks.
  List<Bookmark> getAllBookmarks() {
    return List.unmodifiable(_cache);
  }

  /// Get a bookmark by ID.
  ///
  /// Returns null if the bookmark is not found.
  Bookmark? getBookmarkById(String id) {
    try {
      return _cache.firstWhere((b) => b.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get bookmarks filtered by category.
  ///
  /// Returns a list of bookmarks matching the specified category.
  List<Bookmark> getBookmarksByCategory(BookmarkCategory category) {
    return _cache.where((b) => b.category == category).toList();
  }

  /// Save a new bookmark or update an existing one.
  ///
  /// If a bookmark with the same ID exists, it will be replaced.
  Future<void> saveBookmark(Bookmark bookmark) async {
    try {
      // Remove existing bookmark with same ID if it exists
      _cache.removeWhere((b) => b.id == bookmark.id);

      // Add the new/updated bookmark
      _cache.add(bookmark);

      // Persist to storage
      await _save();
    } catch (e) {
      throw BookmarkDataSourceException('Failed to save bookmark: $e');
    }
  }

  /// Update an existing bookmark.
  ///
  /// Returns true if the bookmark was found and updated.
  /// Returns false if the bookmark was not found.
  Future<bool> updateBookmark(Bookmark bookmark) async {
    try {
      final index = _cache.indexWhere((b) => b.id == bookmark.id);

      if (index == -1) {
        return false; // Bookmark not found
      }

      // Replace the bookmark
      _cache[index] = bookmark;

      // Persist to storage
      await _save();

      return true;
    } catch (e) {
      throw BookmarkDataSourceException('Failed to update bookmark: $e');
    }
  }

  /// Delete a bookmark by ID.
  ///
  /// Returns true if the bookmark was found and deleted.
  /// Returns false if the bookmark was not found.
  Future<bool> deleteBookmark(String id) async {
    try {
      final initialLength = _cache.length;
      _cache.removeWhere((b) => b.id == id);

      if (_cache.length == initialLength) {
        return false; // Bookmark not found
      }

      // Persist to storage
      await _save();

      return true;
    } catch (e) {
      throw BookmarkDataSourceException('Failed to delete bookmark: $e');
    }
  }

  /// Delete all bookmarks.
  Future<void> deleteAllBookmarks() async {
    try {
      _cache.clear();
      await _prefs.remove(_key);
    } catch (e) {
      throw BookmarkDataSourceException('Failed to delete all bookmarks: $e');
    }
  }

  /// Get the count of bookmarks.
  int getBookmarkCount() {
    return _cache.length;
  }

  /// Get the count of bookmarks in a specific category.
  int getBookmarkCountByCategory(BookmarkCategory category) {
    return _cache.where((b) => b.category == category).length;
  }

  /// Check if a bookmark with the given ID exists.
  bool bookmarkExists(String id) {
    return _cache.any((b) => b.id == id);
  }

  /// Serialize a Bookmark to JSON.
  Map<String, dynamic> _bookmarkToJson(Bookmark bookmark) {
    return {
      'id': bookmark.id,
      'name': bookmark.name,
      'location': _locationToJson(bookmark.location),
      'category': bookmark.category.name,
      'createdAt': bookmark.createdAt.toIso8601String(),
      'lastUsedAt': bookmark.lastUsedAt?.toIso8601String(),
    };
  }

  /// Deserialize a Bookmark from JSON.
  Bookmark _bookmarkFromJson(Map<String, dynamic> json) {
    return Bookmark(
      id: json['id'] as String,
      name: json['name'] as String,
      location: _locationFromJson(json['location'] as Map<String, dynamic>),
      category: _categoryFromString(json['category'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.parse(json['lastUsedAt'] as String)
          : null,
    );
  }

  /// Serialize a Location to JSON.
  Map<String, dynamic> _locationToJson(Location location) {
    return {
      'latitude': location.latitude,
      'longitude': location.longitude,
      'altitude': location.altitude,
      'accuracy': location.accuracy,
      'speed': location.speed,
      'heading': location.heading,
      'timestamp': location.timestamp.toIso8601String(),
    };
  }

  /// Deserialize a Location from JSON.
  Location _locationFromJson(Map<String, dynamic> json) {
    return Location(
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      altitude: json['altitude'] as double?,
      accuracy: json['accuracy'] as double?,
      speed: json['speed'] as double?,
      heading: json['heading'] as double?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  /// Convert a string to BookmarkCategory enum.
  BookmarkCategory _categoryFromString(String category) {
    switch (category) {
      case 'home':
        return BookmarkCategory.home;
      case 'work':
        return BookmarkCategory.work;
      case 'favorite':
        return BookmarkCategory.favorite;
      case 'other':
        return BookmarkCategory.other;
      default:
        return BookmarkCategory.other;
    }
  }
}

/// Exception thrown when bookmark data source operations fail.
class BookmarkDataSourceException implements Exception {
  final String message;

  BookmarkDataSourceException(this.message);

  @override
  String toString() => 'BookmarkDataSourceException: $message';
}
