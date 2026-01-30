import 'dart:math';
import 'package:rikera_app/core/utils/result.dart';
import 'package:rikera_app/core/errors/app_errors.dart';
import 'package:rikera_app/core/utils/logger.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/domain/repositories/search_repository.dart';
import 'package:rikera_app/features/map/data/datasources/search_datasource.dart';

/// Implementation of [SearchRepository] using CoMaps search APIs.
///
/// This repository provides search functionality within downloaded map regions,
/// with result ranking by relevance and distance, and caching of recent searches.
/// It registers with the memory management service to clear cache when needed.
///
/// Requirements: 7.1, 7.4, 11.2
class SearchRepositoryImpl implements SearchRepository {
  final AppLogger _logger = const AppLogger('SearchRepository');
  final SearchDataSource _searchDataSource;

  /// Cache for recent search queries and their results.
  /// Key is the search query, value is the list of results.
  final Map<String, List<SearchResult>> _searchCache = {};

  /// Maximum number of cached searches to keep.
  static const int _maxCachedSearches = 20;

  /// List of recent search queries (for LRU cache eviction).
  final List<String> _recentQueries = [];

  SearchRepositoryImpl(this._searchDataSource);

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

      // Perform search using native API
      final rawResults = await _searchDataSource.search(
        query: query,
        lat: nearLocation?.latitude,
        lon: nearLocation?.longitude,
      );

      _logger.debug('Received ${rawResults.length} search results from native');

      // Convert raw results to SearchResult entities
      final results = rawResults.asMap().entries.map((entry) {
        final index = entry.key;
        final raw = entry.value;
        final name = raw['name'] as String? ?? '';
        final address = raw['address'] as String?;
        final lat = raw['lat'] as double? ?? 0.0;
        final lon = raw['lon'] as double? ?? 0.0;

        // Calculate distance if nearLocation is provided
        double? distanceMeters;
        if (nearLocation != null) {
          distanceMeters = _calculateDistance(
            nearLocation.latitude,
            nearLocation.longitude,
            lat,
            lon,
          );
        }

        // Generate a unique ID for this result
        final id = 'search_${DateTime.now().millisecondsSinceEpoch}_$index';

        return SearchResult(
          id: id,
          name: name,
          address: address,
          location: Location(
            latitude: lat,
            longitude: lon,
            timestamp: DateTime.now(),
          ),
          type: SearchResultType.poi, // Default to POI, could be enhanced later
          distanceMeters: distanceMeters,
        );
      }).toList();

      // Sort by distance if nearLocation is provided
      if (nearLocation != null) {
        results.sort((a, b) {
          final distA = a.distanceMeters ?? double.infinity;
          final distB = b.distanceMeters ?? double.infinity;
          return distA.compareTo(distB);
        });
      }

      // Limit results
      final limitedResults = results.take(maxResults).toList();

      // Cache the results
      _cacheSearchResults(cacheKey, limitedResults);

      _logger.debug('Returning ${limitedResults.length} search results');
      return Result.success(limitedResults);
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

  /// Calculates the distance between two coordinates using the Haversine formula.
  /// Returns distance in meters.
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters
    
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * asin(sqrt(a));
    
    return earthRadius * c;
  }

  /// Converts degrees to radians.
  double _toRadians(double degrees) {
    return degrees * pi / 180.0;
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
