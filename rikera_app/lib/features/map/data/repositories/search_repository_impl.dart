import 'package:rikera_app/core/utils/result.dart';
import 'package:rikera_app/core/errors/app_errors.dart';
import 'package:rikera_app/core/utils/logger.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/domain/repositories/search_repository.dart';

/// Implementation of [SearchRepository] using CoMaps search APIs.
///
/// This repository provides search functionality within downloaded map regions,
/// with result ranking by relevance and distance, and caching of recent searches.
/// It registers with the memory management service to clear cache when needed.
///
/// Requirements: 7.1, 7.4, 11.2
class SearchRepositoryImpl implements SearchRepository {
  final AppLogger _logger = const AppLogger('SearchRepository');

  /// Cache for recent search queries and their results.
  /// Key is the search query, value is the list of results.
  final Map<String, List<SearchResult>> _searchCache = {};

  /// Maximum number of cached searches to keep.
  static const int _maxCachedSearches = 20;

  /// List of recent search queries (for LRU cache eviction).
  final List<String> _recentQueries = [];

  @override
  Future<Result<List<SearchResult>>> search({
    required String query,
    Location? nearLocation,
    int maxResults = 20,
  }) async {
    try {
      _logger.debug('Searching for: $query');

      // Validate query
      if (query.trim().isEmpty) {
        _logger.debug('Empty search query');
        return Result.success([]);
      }

      // Check cache first
      final cacheKey = _getCacheKey(query, nearLocation);
      if (_searchCache.containsKey(cacheKey)) {
        _logger.debug('Returning cached search results');
        return Result.success(_searchCache[cacheKey]!);
      }

      // TODO: Implement actual search using agus_maps_flutter
      // For now, return a placeholder error indicating the feature needs implementation
      // This will be implemented when agus_maps_flutter exposes search APIs
      _logger.warning('Search not yet implemented');
      return Result.failure(GenericError.notImplemented());

      // Future implementation will look like:
      // final results = await _searchDataSource.search(
      //   query: query,
      //   nearLocation: nearLocation,
      //   maxResults: maxResults,
      // );
      //
      // // Filter results to downloaded regions only
      // final filteredResults = await _filterToDownloadedRegions(results);
      //
      // // Rank results by relevance and distance
      // final rankedResults = _rankResults(filteredResults, nearLocation);
      //
      // // Cache the results
      // _cacheSearchResults(cacheKey, rankedResults);
      //
      // return Result.success(rankedResults);
    } catch (e, stackTrace) {
      _logger.error('Search failed', error: e, stackTrace: stackTrace);
      return Result.failure(SearchError.searchFailed('$e'));
    }
  }

  @override
  Future<Result<List<SearchResult>>> searchByCategory({
    required SearchCategory category,
    Location? nearLocation,
    int maxResults = 20,
  }) async {
    try {
      _logger.debug('Searching by category: $category');

      // TODO: Implement category search using agus_maps_flutter
      // For now, return a placeholder error
      _logger.warning('Category search not yet implemented');
      return Result.failure(GenericError.notImplemented());

      // Future implementation will look like:
      // final results = await _searchDataSource.searchByCategory(
      //   category: category,
      //   nearLocation: nearLocation,
      //   maxResults: maxResults,
      // );
      //
      // // Filter results to downloaded regions only
      // final filteredResults = await _filterToDownloadedRegions(results);
      //
      // // Rank results by distance
      // final rankedResults = _rankResults(filteredResults, nearLocation);
      //
      // return Result.success(rankedResults);
    } catch (e, stackTrace) {
      _logger.error('Category search failed', error: e, stackTrace: stackTrace);
      return Result.failure(SearchError.searchFailed('$e'));
    }
  }

  /// Generates a cache key for a search query.
  String _getCacheKey(String query, Location? nearLocation) {
    if (nearLocation == null) {
      return query.toLowerCase().trim();
    }

    // Include location in cache key (rounded to 2 decimal places)
    final lat = nearLocation.latitude.toStringAsFixed(2);
    final lon = nearLocation.longitude.toStringAsFixed(2);
    return '${query.toLowerCase().trim()}@$lat,$lon';
  }

  /// Caches search results with LRU eviction.
  ///
  /// If the cache is full, removes the least recently used entry.
  void _cacheSearchResults(String cacheKey, List<SearchResult> results) {
    // Update recent queries list (move to front if exists, add if new)
    _recentQueries.remove(cacheKey);
    _recentQueries.insert(0, cacheKey);

    // If cache is full, remove the least recently used entry
    if (_searchCache.length >= _maxCachedSearches) {
      final oldestKey = _recentQueries.removeLast();
      _searchCache.remove(oldestKey);
      _logger.debug('Evicted oldest search result from cache');
    }

    // Add to cache
    _searchCache[cacheKey] = results;
    _logger.debug('Cached search results (cache size: ${_searchCache.length})');
  }

  /// Clears the search cache to free memory.
  ///
  /// This should be called when search results are no longer needed,
  /// such as when the user navigates away from the search screen.
  void clearCache() {
    final size = _searchCache.length;
    _searchCache.clear();
    _recentQueries.clear();
    _logger.info('Search cache cleared ($size entries removed)');
  }

  /// Gets the list of recent search queries.
  List<String> getRecentQueries() {
    return List.unmodifiable(_recentQueries);
  }

  /// Gets cache statistics for monitoring.
  Map<String, dynamic> getCacheStats() {
    return {
      'size': _searchCache.length,
      'maxSize': _maxCachedSearches,
      'recentQueriesCount': _recentQueries.length,
    };
  }
}
