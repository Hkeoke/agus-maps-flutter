import 'package:rikera_app/core/utils/result.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';

/// Repository interface for place search functionality.
///
/// This repository provides search capabilities within downloaded map regions,
/// supporting both text-based queries and category-based searches.
/// All searches are performed offline using local map data.
///
/// Requirements: 7.1, 7.4
abstract class SearchRepository {
  /// Searches for places matching the given query.
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
  /// Requirements: 7.1, 7.2, 7.3
  Future<Result<List<SearchResult>>> search({
    required String query,
    Location? nearLocation,
    int maxResults = 20,
  });

  /// Searches for places by category.
  ///
  /// This allows users to find places of a specific type (e.g., restaurants,
  /// gas stations, parking) within downloaded map regions.
  ///
  /// Parameters:
  /// - [category]: The category to search for
  /// - [nearLocation]: Optional location to prioritize nearby results
  /// - [maxResults]: Maximum number of results to return (default: 20)
  ///
  /// Returns a [Result] containing a list of [SearchResult] objects,
  /// or an error if the search fails.
  ///
  /// Requirements: 7.4
  Future<Result<List<SearchResult>>> searchByCategory({
    required SearchCategory category,
    Location? nearLocation,
    int maxResults = 20,
  });
}

/// Categories for place search.
///
/// These categories correspond to common point-of-interest types
/// available in the map data.
enum SearchCategory {
  /// Restaurants and food establishments.
  restaurant,

  /// Gas stations and fuel services.
  gasStation,

  /// Parking facilities.
  parking,

  /// Hotels and accommodations.
  hotel,

  /// Shopping centers and stores.
  shopping,

  /// Tourist attractions and landmarks.
  attraction,

  /// Banks and ATMs.
  bank,

  /// Hospitals and medical facilities.
  hospital,

  /// Pharmacies.
  pharmacy,

  /// Police stations.
  police,

  /// All categories.
  all,
}
