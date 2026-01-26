import 'package:rikera_app/core/utils/result.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';

/// Repository interface for bookmark management.
///
/// This repository handles saving, retrieving, updating, and deleting
/// user bookmarks (favorite locations). Bookmarks are persisted locally
/// and organized by category.
///
/// Requirements: 16.1, 16.2, 16.3, 16.6, 16.7, 16.9
abstract class BookmarkRepository {
  /// Retrieves all saved bookmarks.
  ///
  /// Returns a [Result] containing a list of all [Bookmark] objects,
  /// sorted by last used date (most recent first).
  ///
  /// Requirements: 16.1, 16.3
  Future<Result<List<Bookmark>>> getAllBookmarks();

  /// Retrieves bookmarks filtered by category.
  ///
  /// Returns a [Result] containing a list of [Bookmark] objects
  /// that match the specified [category], sorted by last used date.
  ///
  /// Requirements: 16.9
  Future<Result<List<Bookmark>>> getBookmarksByCategory(
    BookmarkCategory category,
  );

  /// Retrieves a specific bookmark by its ID.
  ///
  /// Returns a [Result] containing the [Bookmark] if found,
  /// or null if no bookmark exists with the given ID.
  ///
  /// Requirements: 16.1
  Future<Result<Bookmark?>> getBookmarkById(String id);

  /// Saves a new bookmark.
  ///
  /// The bookmark is persisted to local storage and will be available
  /// across app restarts.
  ///
  /// If a bookmark with the same ID already exists, this will fail.
  /// Use [updateBookmark] to modify existing bookmarks.
  ///
  /// Requirements: 16.2, 16.8
  Future<Result<void>> saveBookmark(Bookmark bookmark);

  /// Updates an existing bookmark.
  ///
  /// This allows changing the bookmark's name, category, or other properties.
  /// The bookmark's ID must match an existing bookmark.
  ///
  /// Requirements: 16.7
  Future<Result<void>> updateBookmark(Bookmark bookmark);

  /// Deletes a bookmark by its ID.
  ///
  /// The bookmark is removed from local storage and will no longer
  /// appear in bookmark lists or on the map.
  ///
  /// Requirements: 16.6
  Future<Result<void>> deleteBookmark(String id);
}
