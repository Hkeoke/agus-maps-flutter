import 'package:agus_maps_flutter/agus_maps_flutter.dart';
import 'package:rikera_app/core/utils/logger.dart';

/// Data source for search operations using CoMaps search APIs.
///
/// This data source provides direct access to the native search functionality.
class SearchDataSource {
  final AppLogger _logger = const AppLogger('SearchDataSource');
  final AgusMapController _mapController;

  SearchDataSource(this._mapController);

  /// Search for places matching the given query.
  ///
  /// [query]: The search text (place name, address, etc.)
  /// [lat], [lon]: Optional location to prioritize nearby results
  ///
  /// Returns a list of raw search results from the native engine.
  Future<List<Map<String, dynamic>>> search({
    required String query,
    double? lat,
    double? lon,
  }) async {
    try {
      _logger.debug('Searching for: $query (lat: $lat, lon: $lon)');
      
      final results = await _mapController.search(
        query,
        lat: lat,
        lon: lon,
      );
      
      _logger.debug('Received ${results.length} results from native');
      return results;
    } catch (e, stackTrace) {
      _logger.error('Search failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Cancel any ongoing search operations.
  Future<void> cancelSearch() async {
    try {
      await _mapController.cancelSearch();
      _logger.debug('Search cancelled');
    } catch (e, stackTrace) {
      _logger.error('Failed to cancel search', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
