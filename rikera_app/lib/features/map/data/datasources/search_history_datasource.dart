import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Data source for persisting search history using SharedPreferences.
///
/// This data source handles saving and loading recent search queries,
/// maintaining a list of up to 20 recent searches.
///
/// Requirements: 12.4
class SearchHistoryDataSource {
  static const String _keySearchHistory = 'search_history';
  static const int _maxHistorySize = 20;

  final SharedPreferences _prefs;
  List<String> _cache = [];

  SearchHistoryDataSource._(this._prefs);

  /// Create and initialize the search history data source
  static Future<SearchHistoryDataSource> create() async {
    final prefs = await SharedPreferences.getInstance();
    final dataSource = SearchHistoryDataSource._(prefs);
    await dataSource._load();
    return dataSource;
  }

  /// Load search history from shared preferences.
  Future<void> _load() async {
    try {
      final json = _prefs.getString(_keySearchHistory);
      if (json != null) {
        final list = jsonDecode(json) as List;
        _cache = list.cast<String>();
      }
    } catch (e) {
      // If parsing fails, start with empty list
      _cache = [];
    }
  }

  /// Save search history to shared preferences.
  Future<void> _save() async {
    try {
      final json = jsonEncode(_cache);
      await _prefs.setString(_keySearchHistory, json);
    } catch (e) {
      throw SearchHistoryDataSourceException(
        'Failed to save search history: $e',
      );
    }
  }

  /// Get all search history queries.
  ///
  /// Returns an unmodifiable list of recent search queries,
  /// ordered from most recent to oldest.
  List<String> getSearchHistory() {
    return List.unmodifiable(_cache);
  }

  /// Add a search query to the history.
  ///
  /// If the query already exists, it will be moved to the top.
  /// The history is limited to [_maxHistorySize] entries.
  Future<void> addSearchQuery(String query) async {
    if (query.trim().isEmpty) {
      return;
    }

    try {
      // Remove the query if it already exists
      _cache.remove(query);

      // Add to the beginning (most recent)
      _cache.insert(0, query);

      // Limit to max size
      if (_cache.length > _maxHistorySize) {
        _cache = _cache.sublist(0, _maxHistorySize);
      }

      // Persist to storage
      await _save();
    } catch (e) {
      throw SearchHistoryDataSourceException('Failed to add search query: $e');
    }
  }

  /// Remove a specific search query from the history.
  ///
  /// Returns true if the query was found and removed.
  Future<bool> removeSearchQuery(String query) async {
    try {
      final removed = _cache.remove(query);

      if (removed) {
        await _save();
      }

      return removed;
    } catch (e) {
      throw SearchHistoryDataSourceException(
        'Failed to remove search query: $e',
      );
    }
  }

  /// Clear all search history.
  Future<void> clearSearchHistory() async {
    try {
      _cache.clear();
      await _prefs.remove(_keySearchHistory);
    } catch (e) {
      throw SearchHistoryDataSourceException(
        'Failed to clear search history: $e',
      );
    }
  }

  /// Get the count of search history entries.
  int getHistoryCount() {
    return _cache.length;
  }

  /// Check if a query exists in the history.
  bool containsQuery(String query) {
    return _cache.contains(query);
  }
}

/// Exception thrown when search history data source operations fail.
class SearchHistoryDataSourceException implements Exception {
  final String message;

  SearchHistoryDataSourceException(this.message);

  @override
  String toString() => 'SearchHistoryDataSourceException: $message';
}
