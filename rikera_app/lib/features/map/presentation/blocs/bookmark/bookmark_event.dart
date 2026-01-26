import 'package:rikera_app/features/map/domain/entities/entities.dart';

/// Base class for bookmark events.
abstract class BookmarkEvent {
  const BookmarkEvent();
}

/// Event to load all bookmarks.
///
/// This fetches all saved bookmarks from storage.
///
/// Requirements: 16.1, 16.3
class LoadBookmarks extends BookmarkEvent {
  const LoadBookmarks();
}

/// Event to save a bookmark (create or update).
///
/// This persists a bookmark to storage.
///
/// Requirements: 16.2, 16.6
class SaveBookmark extends BookmarkEvent {
  final Bookmark bookmark;

  const SaveBookmark(this.bookmark);
}

/// Event to update an existing bookmark.
///
/// This is an alias for SaveBookmark but makes the intent clearer.
///
/// Requirements: 16.6
class UpdateBookmark extends BookmarkEvent {
  final Bookmark bookmark;

  const UpdateBookmark(this.bookmark);
}

/// Event to delete a bookmark.
///
/// This removes a bookmark from storage.
///
/// Requirements: 16.7
class DeleteBookmark extends BookmarkEvent {
  final String bookmarkId;

  const DeleteBookmark(this.bookmarkId);
}

/// Event to filter bookmarks by category.
///
/// This filters the displayed bookmarks to show only those in the
/// specified category.
///
/// Requirements: 16.9
class FilterByCategory extends BookmarkEvent {
  final BookmarkCategory? category;

  const FilterByCategory(this.category);
}
