import 'package:rikera_app/core/errors/app_errors.dart';
import 'package:rikera_app/core/utils/result.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/domain/repositories/repositories.dart';

/// Use case for saving a bookmark.
///
/// This use case handles creating new bookmarks and updating existing ones.
///
/// Requirements: 16.2, 16.6
class SaveBookmarkUseCase {
  final BookmarkRepository _repository;

  const SaveBookmarkUseCase(this._repository);

  /// Saves a bookmark (creates new or updates existing).
  ///
  /// If the bookmark has an existing ID, it will be updated.
  /// If the bookmark has a new ID, it will be created.
  ///
  /// The bookmark is persisted to local storage and will be available
  /// across app restarts.
  ///
  /// Returns a [Result] indicating success or failure.
  ///
  /// Requirements: 16.2, 16.6
  Future<Result<void>> execute(Bookmark bookmark) async {
    try {
      // Validate bookmark
      if (bookmark.name.trim().isEmpty) {
        return Result.failure(
          GenericError.validation('Bookmark name cannot be empty'),
        );
      }

      // Check if bookmark already exists
      final existingResult = await _repository.getBookmarkById(bookmark.id);

      if (existingResult.isSuccess && existingResult.valueOrNull != null) {
        // Update existing bookmark
        return await _repository.updateBookmark(bookmark);
      } else {
        // Save new bookmark
        return await _repository.saveBookmark(bookmark);
      }
    } catch (e, stackTrace) {
      return Result.failure(
        GenericError.unknown('Failed to save bookmark: $e', stackTrace),
      );
    }
  }
}
