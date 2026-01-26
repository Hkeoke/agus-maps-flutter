import 'package:rikera_app/core/utils/result.dart';
import 'package:rikera_app/core/errors/app_errors.dart';
import 'package:rikera_app/core/utils/logger.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/domain/repositories/bookmark_repository.dart';
import 'package:rikera_app/features/map/data/datasources/bookmark_datasource.dart';

/// Implementation of [BookmarkRepository] using local storage.
///
/// This repository manages bookmarks with CRUD operations, category filtering,
/// and sorting by last used date.
///
/// Requirements: 16.1, 16.2, 16.3, 16.6, 16.7, 16.9
class BookmarkRepositoryImpl implements BookmarkRepository {
  final BookmarkDataSource _bookmarkDataSource;
  final AppLogger _logger = const AppLogger('BookmarkRepository');

  BookmarkRepositoryImpl({required BookmarkDataSource bookmarkDataSource})
    : _bookmarkDataSource = bookmarkDataSource;

  @override
  Future<Result<List<Bookmark>>> getAllBookmarks() async {
    try {
      _logger.debug('Fetching all bookmarks');
      final bookmarks = _bookmarkDataSource.getAllBookmarks();

      // Sort by last used date (most recent first), then by created date
      bookmarks.sort((a, b) {
        // If both have lastUsedAt, compare them
        if (a.lastUsedAt != null && b.lastUsedAt != null) {
          return b.lastUsedAt!.compareTo(a.lastUsedAt!);
        }

        // If only one has lastUsedAt, it comes first
        if (a.lastUsedAt != null) return -1;
        if (b.lastUsedAt != null) return 1;

        // If neither has lastUsedAt, compare by created date
        return b.createdAt.compareTo(a.createdAt);
      });

      _logger.info('Fetched ${bookmarks.length} bookmarks');
      return Result.success(bookmarks);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to fetch bookmarks',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(StorageError.readFailure());
    }
  }

  @override
  Future<Result<List<Bookmark>>> getBookmarksByCategory(
    BookmarkCategory category,
  ) async {
    try {
      _logger.debug('Fetching bookmarks for category: $category');
      final allBookmarks = _bookmarkDataSource.getAllBookmarks();

      // Filter by category
      final filteredBookmarks = allBookmarks
          .where((bookmark) => bookmark.category == category)
          .toList();

      // Sort by last used date (most recent first), then by created date
      filteredBookmarks.sort((a, b) {
        // If both have lastUsedAt, compare them
        if (a.lastUsedAt != null && b.lastUsedAt != null) {
          return b.lastUsedAt!.compareTo(a.lastUsedAt!);
        }

        // If only one has lastUsedAt, it comes first
        if (a.lastUsedAt != null) return -1;
        if (b.lastUsedAt != null) return 1;

        // If neither has lastUsedAt, compare by created date
        return b.createdAt.compareTo(a.createdAt);
      });

      _logger.info(
        'Fetched ${filteredBookmarks.length} bookmarks for category: $category',
      );
      return Result.success(filteredBookmarks);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to fetch bookmarks by category',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(StorageError.readFailure());
    }
  }

  @override
  Future<Result<Bookmark?>> getBookmarkById(String id) async {
    try {
      _logger.debug('Fetching bookmark by id: $id');
      final allBookmarks = _bookmarkDataSource.getAllBookmarks();
      final bookmark = allBookmarks.where((b) => b.id == id).firstOrNull;

      if (bookmark != null) {
        _logger.debug('Found bookmark: $id');
      } else {
        _logger.debug('Bookmark not found: $id');
      }

      return Result.success(bookmark);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to fetch bookmark by id: $id',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(StorageError.readFailure());
    }
  }

  @override
  Future<Result<void>> saveBookmark(Bookmark bookmark) async {
    try {
      _logger.info('Saving bookmark: ${bookmark.name}');
      await _bookmarkDataSource.saveBookmark(bookmark);
      _logger.info('Bookmark saved successfully: ${bookmark.name}');
      return Result.success(null);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to save bookmark: ${bookmark.name}',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(StorageError.writeFailure());
    }
  }

  @override
  Future<Result<void>> updateBookmark(Bookmark bookmark) async {
    try {
      _logger.info('Updating bookmark: ${bookmark.name}');
      // Update is the same as save in this implementation
      // The data source will overwrite the existing bookmark with the same ID
      await _bookmarkDataSource.saveBookmark(bookmark);
      _logger.info('Bookmark updated successfully: ${bookmark.name}');
      return Result.success(null);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to update bookmark: ${bookmark.name}',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(StorageError.writeFailure());
    }
  }

  @override
  Future<Result<void>> deleteBookmark(String id) async {
    try {
      _logger.info('Deleting bookmark: $id');
      await _bookmarkDataSource.deleteBookmark(id);
      _logger.info('Bookmark deleted successfully: $id');
      return Result.success(null);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to delete bookmark: $id',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(StorageError.writeFailure());
    }
  }

  /// Updates the last used timestamp for a bookmark.
  ///
  /// This is useful when a user selects a bookmark to navigate to it,
  /// allowing the app to show recently used bookmarks first.
  Future<Result<void>> markBookmarkAsUsed(String id) async {
    try {
      _logger.debug('Marking bookmark as used: $id');
      final result = await getBookmarkById(id);

      if (!result.isSuccess || result.valueOrNull == null) {
        _logger.warning('Bookmark not found for marking as used: $id');
        return Result.failure(
          GenericError.invalidState('Bookmark not found: $id'),
        );
      }

      final bookmark = result.valueOrNull!;
      final updatedBookmark = Bookmark(
        id: bookmark.id,
        name: bookmark.name,
        location: bookmark.location,
        category: bookmark.category,
        createdAt: bookmark.createdAt,
        lastUsedAt: DateTime.now(),
      );

      return await updateBookmark(updatedBookmark);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to mark bookmark as used: $id',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(StorageError.writeFailure());
    }
  }
}
