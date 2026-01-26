import 'package:rikera_app/core/utils/result.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/domain/repositories/repositories.dart';

/// Use case for retrieving bookmarks.
///
/// This use case provides access to saved bookmarks, with optional
/// filtering by category.
///
/// Requirements: 16.1, 16.3, 16.9
class GetBookmarksUseCase {
  final BookmarkRepository _repository;

  const GetBookmarksUseCase(this._repository);

  /// Retrieves all bookmarks or bookmarks filtered by category.
  ///
  /// If [category] is provided, only bookmarks in that category are returned.
  /// If [category] is null, all bookmarks are returned.
  ///
  /// Bookmarks are sorted by last used date (most recent first), with
  /// bookmarks that have never been used sorted by creation date.
  ///
  /// Returns a [Result] containing a list of [Bookmark] objects,
  /// or an error if retrieval fails.
  ///
  /// Requirements: 16.1, 16.3, 16.9
  Future<Result<List<Bookmark>>> execute({BookmarkCategory? category}) async {
    if (category != null) {
      return await _repository.getBookmarksByCategory(category);
    } else {
      return await _repository.getAllBookmarks();
    }
  }
}
