import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rikera_app/features/map/data/datasources/search_history_datasource.dart';
import 'package:rikera_app/features/map/domain/usecases/usecases.dart';
import 'search_event.dart';
import 'search_state.dart';

/// Bloc for managing place search.
///
/// This bloc handles:
/// - Searching for places by query with debouncing
/// - Displaying search results
/// - Handling result selection
/// - Clearing search
/// - Managing search history
///
/// Requirements: 7.1, 7.2, 7.5, 12.4
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final SearchPlacesUseCase _searchPlacesUseCase;
  final SearchHistoryDataSource? _searchHistoryDataSource;

  /// Timer for debouncing search queries.
  Timer? _debounceTimer;

  /// Debounce duration for search queries (300ms).
  /// This reduces unnecessary searches while the user is typing.
  ///
  /// Requirements: 7.1
  static const Duration _debounceDuration = Duration(milliseconds: 300);

  SearchBloc({
    required SearchPlacesUseCase searchPlacesUseCase,
    SearchHistoryDataSource? searchHistoryDataSource,
  }) : _searchPlacesUseCase = searchPlacesUseCase,
       _searchHistoryDataSource = searchHistoryDataSource,
       super(const SearchInitial()) {
    on<SearchQuery>(_onSearchQuery);
    on<SelectResult>(_onSelectResult);
    on<ClearSearch>(_onClearSearch);
    on<LoadSearchHistory>(_onLoadSearchHistory);
    on<RemoveSearchHistoryItem>(_onRemoveSearchHistoryItem);
    on<ClearSearchHistory>(_onClearSearchHistory);
  }

  /// Handles the SearchQuery event.
  ///
  /// This performs a search using the SearchPlacesUseCase, which searches
  /// within downloaded map regions only. The query is also saved to search history.
  ///
  /// Search queries are debounced by 300ms to reduce unnecessary searches
  /// while the user is typing.
  ///
  /// Requirements: 7.1, 12.4
  Future<void> _onSearchQuery(
    SearchQuery event,
    Emitter<SearchState> emit,
  ) async {
    // Cancel any pending debounce timer
    _debounceTimer?.cancel();

    // Validate query
    if (event.query.trim().isEmpty) {
      emit(const SearchError('Search query cannot be empty'));
      return;
    }

    // Emit searching state immediately to show loading indicator
    emit(SearchSearching(event.query));

    // Create a completer to handle the debounced search
    final completer = Completer<void>();

    // Start debounce timer
    _debounceTimer = Timer(_debounceDuration, () async {
      try {
        // Perform search
        final result = await _searchPlacesUseCase.execute(
          query: event.query,
          nearLocation: event.nearLocation,
          maxResults: event.maxResults,
        );

        // Save to search history
        await _saveToHistory(event.query);

        // Handle result
        if (result.isSuccess) {
          emit(
            SearchResults(
              query: event.query,
              results: result.valueOrNull ?? [],
            ),
          );
        } else {
          emit(SearchError(result.errorOrNull?.message ?? 'Unknown error'));
        }
      } catch (e) {
        emit(SearchError('Search failed: $e'));
      } finally {
        completer.complete();
      }
    });

    // Wait for the debounced search to complete
    await completer.future;
  }

  /// Handles the SelectResult event.
  ///
  /// This emits a state indicating that a result has been selected,
  /// allowing the UI to respond appropriately (e.g., center map on location).
  ///
  /// Requirements: 7.3
  Future<void> _onSelectResult(
    SelectResult event,
    Emitter<SearchState> emit,
  ) async {
    emit(SearchResultSelected(event.result));
  }

  /// Handles the ClearSearch event.
  ///
  /// This clears the search results and returns to the initial state.
  Future<void> _onClearSearch(
    ClearSearch event,
    Emitter<SearchState> emit,
  ) async {
    emit(const SearchInitial());
  }

  /// Handles the LoadSearchHistory event.
  ///
  /// This loads the search history from persistent storage.
  ///
  /// Requirements: 12.4
  Future<void> _onLoadSearchHistory(
    LoadSearchHistory event,
    Emitter<SearchState> emit,
  ) async {
    if (_searchHistoryDataSource == null) return;

    try {
      final history = _searchHistoryDataSource.getSearchHistory();
      emit(SearchHistoryLoaded(history));
    } catch (e) {
      // If loading fails, emit empty history
      emit(const SearchHistoryLoaded([]));
    }
  }

  /// Handles the RemoveSearchHistoryItem event.
  ///
  /// This removes a specific query from the search history.
  ///
  /// Requirements: 12.4
  Future<void> _onRemoveSearchHistoryItem(
    RemoveSearchHistoryItem event,
    Emitter<SearchState> emit,
  ) async {
    if (_searchHistoryDataSource == null) return;

    try {
      await _searchHistoryDataSource.removeSearchQuery(event.query);
      final history = _searchHistoryDataSource.getSearchHistory();
      emit(SearchHistoryLoaded(history));
    } catch (e) {
      // If removal fails, reload current history
      final history = _searchHistoryDataSource.getSearchHistory();
      emit(SearchHistoryLoaded(history));
    }
  }

  /// Handles the ClearSearchHistory event.
  ///
  /// This clears all search history.
  ///
  /// Requirements: 12.4
  Future<void> _onClearSearchHistory(
    ClearSearchHistory event,
    Emitter<SearchState> emit,
  ) async {
    if (_searchHistoryDataSource == null) return;

    try {
      await _searchHistoryDataSource.clearSearchHistory();
      emit(const SearchHistoryLoaded([]));
    } catch (e) {
      // If clearing fails, reload current history
      final history = _searchHistoryDataSource.getSearchHistory();
      emit(SearchHistoryLoaded(history));
    }
  }

  /// Saves a query to search history.
  ///
  /// This is called automatically after a successful search.
  Future<void> _saveToHistory(String query) async {
    if (_searchHistoryDataSource == null) return;

    try {
      await _searchHistoryDataSource.addSearchQuery(query);
    } catch (e) {
      // If saving fails, continue without history
      // Error is silently ignored as this is not critical
    }
  }

  /// Gets the current search history.
  ///
  /// Returns an empty list if history is not available.
  List<String> getSearchHistory() {
    if (_searchHistoryDataSource == null) return [];
    return _searchHistoryDataSource.getSearchHistory();
  }

  @override
  Future<void> close() {
    // Cancel debounce timer when bloc is closed
    _debounceTimer?.cancel();
    return super.close();
  }
}
