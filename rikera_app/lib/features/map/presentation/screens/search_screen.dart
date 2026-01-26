import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rikera_app/features/map/presentation/blocs/blocs.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/domain/repositories/search_repository.dart';

/// Search screen for finding places and addresses.
///
/// This screen provides:
/// - Search input field with clear button
/// - Recent searches list
/// - Category filter chips
/// - Search results display
/// - Empty state handling
///
/// Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 9.1
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Selected category filter (null means all categories)
  SearchCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    // Auto-focus the search field when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
      // Load search history
      context.read<SearchBloc>().add(const LoadSearchHistory());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Performs a search with the current query.
  ///
  /// Requirements: 7.1, 12.4
  void _performSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    // Get current location for distance calculation
    final locationState = context.read<LocationBloc>().state;
    Location? nearLocation;
    if (locationState is LocationTracking) {
      nearLocation = locationState.location;
    }

    // Trigger search (history is saved automatically in the bloc)
    context.read<SearchBloc>().add(
      SearchQuery(query: query, nearLocation: nearLocation),
    );
  }

  /// Clears the search input and results.
  void _clearSearch() {
    _searchController.clear();
    context.read<SearchBloc>().add(const ClearSearch());
    _searchFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Places'), elevation: 2),
      body: Column(
        children: [
          // Search input field
          _buildSearchInput(),

          // Category filters
          _buildCategoryFilters(),

          // Search results or recent searches
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  /// Builds the search input field with clear button.
  ///
  /// Uses large touch targets and high contrast for driving safety.
  ///
  /// Requirements: 7.1, 9.1
  Widget _buildSearchInput() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: const TextStyle(fontSize: 18),
        decoration: InputDecoration(
          hintText: 'Search for places...',
          hintStyle: TextStyle(
            fontSize: 18,
            color: Theme.of(context).hintColor,
          ),
          prefixIcon: const Icon(Icons.search, size: 28),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 28),
                  onPressed: _clearSearch,
                  tooltip: 'Clear search',
                  // Minimum 48dp touch target
                  iconSize: 28,
                  padding: const EdgeInsets.all(12),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).primaryColor,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        textInputAction: TextInputAction.search,
        onChanged: (value) {
          // Rebuild to show/hide clear button
          setState(() {});
        },
        onSubmitted: (_) => _performSearch(),
      ),
    );
  }

  /// Builds the category filter chips.
  ///
  /// Allows filtering search results by category (e.g., restaurants, hotels).
  ///
  /// Requirements: 7.4, 9.1
  Widget _buildCategoryFilters() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildCategoryChip('All', null),
          const SizedBox(width: 8),
          _buildCategoryChip('Food', SearchCategory.restaurant),
          const SizedBox(width: 8),
          _buildCategoryChip('Hotels', SearchCategory.hotel),
          const SizedBox(width: 8),
          _buildCategoryChip('Gas', SearchCategory.gasStation),
          const SizedBox(width: 8),
          _buildCategoryChip('Parking', SearchCategory.parking),
          const SizedBox(width: 8),
          _buildCategoryChip('Shopping', SearchCategory.shopping),
        ],
      ),
    );
  }

  /// Builds a single category filter chip.
  ///
  /// Uses large touch targets (minimum 48dp height) for driving safety.
  ///
  /// Requirements: 9.1
  Widget _buildCategoryChip(String label, SearchCategory? category) {
    final isSelected = _selectedCategory == category;

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedCategory = selected ? category : null;
        });
        // Re-trigger search with new category filter if there's a query
        if (_searchController.text.trim().isNotEmpty) {
          _performSearch();
        }
      },
      selectedColor: Theme.of(context).primaryColor,
      backgroundColor: Theme.of(context).cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      // Ensure minimum 48dp touch target
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }

  /// Builds the main content area.
  ///
  /// Shows either:
  /// - Search results (when search is performed)
  /// - Recent searches (when no search is active)
  /// - Loading indicator (when searching)
  /// - Empty state (when no results found)
  /// - Error message (when search fails)
  Widget _buildContent() {
    return BlocBuilder<SearchBloc, SearchState>(
      builder: (context, state) {
        if (state is SearchSearching) {
          return _buildLoadingState();
        } else if (state is SearchResults) {
          if (state.isEmpty) {
            return _buildEmptyState(state.query);
          }
          return _buildSearchResults(state.results);
        } else if (state is SearchError) {
          return _buildErrorState(state.message);
        } else if (state is SearchResultSelected) {
          // Handle result selection: center map and show navigation options
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleResultSelection(state.result);
          });
          return _buildLoadingState();
        } else if (state is SearchHistoryLoaded) {
          // Show recent searches
          return _buildRecentSearches();
        } else {
          // Initial state - load search history
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<SearchBloc>().add(const LoadSearchHistory());
          });
          return _buildRecentSearches();
        }
      },
    );
  }

  /// Builds the loading state indicator.
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Searching...', style: TextStyle(fontSize: 18)),
        ],
      ),
    );
  }

  /// Builds the empty state when no results are found.
  ///
  /// Requirements: 7.5
  Widget _buildEmptyState(String query) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'No places found for "$query"',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text('Try:', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '• Using different keywords\n'
              '• Checking your spelling\n'
              '• Using more general terms\n'
              '• Downloading maps for this area',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the error state.
  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Search Error',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _performSearch,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the recent searches list.
  ///
  /// Requirements: 7.1, 12.4
  Widget _buildRecentSearches() {
    return BlocBuilder<SearchBloc, SearchState>(
      builder: (context, state) {
        // Get search history from state
        List<String> recentSearches = [];
        if (state is SearchHistoryLoaded) {
          recentSearches = state.history;
        }

        if (recentSearches.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search,
                    size: 64,
                    color: Theme.of(context).disabledColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Search for places',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Find restaurants, hotels, gas stations, and more',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Recent Searches',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: recentSearches.length,
                itemBuilder: (context, index) {
                  final query = recentSearches[index];
                  return ListTile(
                    leading: const Icon(Icons.history, size: 28),
                    title: Text(query, style: const TextStyle(fontSize: 18)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 24),
                      onPressed: () {
                        context.read<SearchBloc>().add(
                          RemoveSearchHistoryItem(query),
                        );
                      },
                      tooltip: 'Remove',
                    ),
                    onTap: () {
                      _searchController.text = query;
                      _performSearch();
                    },
                    // Minimum 48dp touch target
                    minVerticalPadding: 12,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Builds the search results list.
  ///
  /// Displays result name, address, and distance with large touch targets.
  ///
  /// Requirements: 7.2, 9.1
  Widget _buildSearchResults(List<SearchResult> results) {
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        return _buildSearchResultItem(result);
      },
    );
  }

  /// Builds a single search result list item.
  ///
  /// Uses large touch targets (minimum 48dp) and displays:
  /// - Result name (large, bold)
  /// - Address (if available)
  /// - Distance from current location (if available)
  ///
  /// Requirements: 7.2, 9.1
  Widget _buildSearchResultItem(SearchResult result) {
    return InkWell(
      onTap: () {
        // Handle result selection (will be implemented in subtask 11.3)
        context.read<SearchBloc>().add(SelectResult(result));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        // Ensure minimum 48dp touch target
        constraints: const BoxConstraints(minHeight: 72),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon based on result type
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getIconForResultType(result.type),
                size: 28,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(width: 16),

            // Result details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Result name
                  Text(
                    result.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Address (if available)
                  if (result.address != null && result.address!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      result.address!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Distance (if available)
                  if (result.distanceMeters != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatDistance(result.distanceMeters!),
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Chevron icon
            Icon(
              Icons.chevron_right,
              size: 28,
              color: Theme.of(context).disabledColor,
            ),
          ],
        ),
      ),
    );
  }

  /// Returns an appropriate icon for the search result type.
  IconData _getIconForResultType(SearchResultType type) {
    switch (type) {
      case SearchResultType.poi:
        return Icons.place;
      case SearchResultType.address:
        return Icons.home;
      case SearchResultType.city:
        return Icons.location_city;
      case SearchResultType.region:
        return Icons.map;
      case SearchResultType.country:
        return Icons.public;
      case SearchResultType.other:
        return Icons.place;
    }
  }

  /// Formats distance in meters to a human-readable string.
  ///
  /// - Less than 1000m: Shows in meters (e.g., "250 m")
  /// - 1000m or more: Shows in kilometers (e.g., "1.5 km")
  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      final km = meters / 1000;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  /// Handles search result selection.
  ///
  /// Centers the map on the selected location, shows a marker,
  /// and offers navigation options.
  ///
  /// Requirements: 7.3
  void _handleResultSelection(SearchResult result) {
    // Center map on selected location
    context.read<MapCubit>().moveToLocation(result.location, zoom: 16);

    // Pop the search screen to return to map
    Navigator.of(context).pop();

    // Show bottom sheet with navigation options
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildResultDetailsSheet(result),
    );
  }

  /// Builds the bottom sheet showing result details and navigation options.
  ///
  /// Requirements: 7.3
  Widget _buildResultDetailsSheet(SearchResult result) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Result name
          Text(
            result.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // Address (if available)
          if (result.address != null && result.address!.isNotEmpty) ...[
            Text(
              result.address!,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Distance (if available)
          if (result.distanceMeters != null) ...[
            Row(
              children: [
                Icon(
                  Icons.directions_walk,
                  size: 20,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDistance(result.distanceMeters!),
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // Navigate button
          SizedBox(
            width: double.infinity,
            height: 56, // Large touch target
            child: ElevatedButton.icon(
              onPressed: () {
                // Get current location
                final locationState = context.read<LocationBloc>().state;
                Location? currentLocation;
                if (locationState is LocationTracking) {
                  currentLocation = locationState.location;
                }

                if (currentLocation != null) {
                  // Calculate route
                  context.read<RouteBloc>().add(
                    CalculateRoute(
                      origin: currentLocation,
                      destination: result.location,
                    ),
                  );

                  // Close the bottom sheet
                  Navigator.of(context).pop();

                  // Show snackbar
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Calculating route...'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                } else {
                  // No location available
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Location not available. Please enable GPS.',
                      ),
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.navigation, size: 28),
              label: const Text(
                'Navigate Here',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Close button
          SizedBox(
            width: double.infinity,
            height: 56, // Large touch target
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close', style: TextStyle(fontSize: 18)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
