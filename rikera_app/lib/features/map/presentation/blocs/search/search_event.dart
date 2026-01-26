import 'package:rikera_app/features/map/domain/entities/entities.dart';

/// Base class for search events.
abstract class SearchEvent {
  const SearchEvent();
}

/// Event to perform a search query.
///
/// This event triggers a search for places matching the query string.
///
/// Requirements: 7.1
class SearchQuery extends SearchEvent {
  final String query;
  final Location? nearLocation;
  final int maxResults;

  const SearchQuery({
    required this.query,
    this.nearLocation,
    this.maxResults = 20,
  });
}

/// Event to select a search result.
///
/// This event is triggered when the user taps on a search result.
///
/// Requirements: 7.3
class SelectResult extends SearchEvent {
  final SearchResult result;

  const SelectResult(this.result);
}

/// Event to clear the current search.
///
/// This clears search results and returns to the initial state.
class ClearSearch extends SearchEvent {
  const ClearSearch();
}

/// Event to load search history.
///
/// This loads the persisted search history from storage.
///
/// Requirements: 12.4
class LoadSearchHistory extends SearchEvent {
  const LoadSearchHistory();
}

/// Event to remove a specific item from search history.
///
/// Requirements: 12.4
class RemoveSearchHistoryItem extends SearchEvent {
  final String query;

  const RemoveSearchHistoryItem(this.query);
}

/// Event to clear all search history.
///
/// Requirements: 12.4
class ClearSearchHistory extends SearchEvent {
  const ClearSearchHistory();
}
