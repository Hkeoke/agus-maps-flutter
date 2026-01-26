import 'package:rikera_app/core/utils/result.dart';
import 'package:rikera_app/features/map/domain/repositories/repositories.dart';

/// Use case for deleting a bookmark.
///
/// This use case removes a bookmark from storage, making it unavailable
/// for future use.
///
/// Requirements: 16.7
class DeleteBookmarkUseCase {
  final BookmarkRepository _repository;

  const DeleteBookmarkUseCase(this._repository);

  /// Deletes the bookmark with the specified [bookmarkId].
  ///
  /// The bookmark is removed from local storage and will no longer
  /// appear in bookmark lists or on the map.
  ///
  /// Returns a [Result] indicating success or failure.
  /// If the bookmark doesn't exist, the operation succeeds (idempotent).
  ///
  /// Requirements: 16.7
  Future<Result<void>> execute(String bookmarkId) async {
    return await _repository.deleteBookmark(bookmarkId);
  }
}
