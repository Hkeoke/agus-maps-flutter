import 'package:rikera_app/features/map/domain/entities/entities.dart';

/// Base class for search states.
abstract class SearchState {
  const SearchState();
}

/// Initial state before any search has been performed.
class SearchInitial extends SearchState {
  const SearchInitial();

  @override
  bool operator ==(Object other) => other is SearchInitial;

  @override
  int get hashCode => 0;
}

/// State when a search is in progress.
///
/// Requirements: 7.1
class SearchSearching extends SearchState {
  final String query;

  const SearchSearching(this.query);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchSearching && other.query == query;
  }

  @override
  int get hashCode => query.hashCode;

  @override
  String toString() => 'SearchSearching(query: $query)';
}

/// State when search results are available.
///
/// This state contains the list of search results matching the query.
///
/// Requirements: 7.2
class SearchResults extends SearchState {
  final String query;
  final List<SearchResult> results;

  const SearchResults({required this.query, required this.results});

  /// Returns true if there are no results
  bool get isEmpty => results.isEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchResults &&
        other.query == query &&
        _listEquals(other.results, results);
  }

  @override
  int get hashCode => query.hashCode ^ results.hashCode;

  @override
  String toString() => 'SearchResults(query: $query, count: ${results.length})';

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// State when a search result has been selected.
///
/// This state is emitted when the user taps on a search result,
/// allowing the UI to respond (e.g., center map, show details).
///
/// Requirements: 7.3
class SearchResultSelected extends SearchState {
  final SearchResult result;

  const SearchResultSelected(this.result);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchResultSelected && other.result == result;
  }

  @override
  int get hashCode => result.hashCode;

  @override
  String toString() => 'SearchResultSelected(${result.name})';
}

/// State when search fails.
///
/// Requirements: 7.5
class SearchError extends SearchState {
  final String message;

  const SearchError(this.message);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchError && other.message == message;
  }

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'SearchError($message)';
}

/// State when search history is loaded.
///
/// This state contains the list of recent search queries.
///
/// Requirements: 12.4
class SearchHistoryLoaded extends SearchState {
  final List<String> history;

  const SearchHistoryLoaded(this.history);

  /// Returns true if there is no history
  bool get isEmpty => history.isEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchHistoryLoaded && _listEquals(other.history, history);
  }

  @override
  int get hashCode => history.hashCode;

  @override
  String toString() => 'SearchHistoryLoaded(count: ${history.length})';

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
