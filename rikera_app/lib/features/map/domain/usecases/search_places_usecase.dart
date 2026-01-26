import 'package:rikera_app/core/errors/app_errors.dart';
import 'package:rikera_app/core/utils/result.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/domain/repositories/repositories.dart';

/// Use case for searching places within downloaded map regions.
///
/// This use case provides offline place search functionality, ensuring
/// all results come from downloaded regions only. Results are ranked by
/// relevance and distance from the user's location.
///
/// Requirements: 7.1
class SearchPlacesUseCase {
  final SearchRepository _repository;

  const SearchPlacesUseCase(this._repository);

  /// Searches for places matching the given [query].
  ///
  /// The search is performed within downloaded map regions only,
  /// ensuring offline functionality. Results are ranked by:
  /// - Relevance to the query
  /// - Distance from [nearLocation] (if provided)
  ///
  /// Parameters:
  /// - [query]: The search text (place name, address, etc.)
  /// - [nearLocation]: Optional location to prioritize nearby results
  /// - [maxResults]: Maximum number of results to return (default: 20)
  ///
  /// Returns a [Result] containing a list of [SearchResult] objects,
  /// or an error if the search fails.
  ///
  /// Requirements: 7.1
  Future<Result<List<SearchResult>>> execute({
    required String query,
    Location? nearLocation,
    int maxResults = 20,
  }) async {
    // Validate query
    if (query.trim().isEmpty) {
      return Result.failure(SearchError.invalidQuery());
    }

    // Delegate to repository which handles:
    // - Searching within downloaded regions only
    // - Ranking by relevance and distance
    // - Caching recent searches
    return await _repository.search(
      query: query,
      nearLocation: nearLocation,
      maxResults: maxResults,
    );
  }
}
