import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rikera_app/features/map/presentation/blocs/blocs.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/presentation/widgets/widgets.dart';
import 'package:rikera_app/core/theme/theme.dart';

/// Search screen for finding places and addresses.
///
/// Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 9.1
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Load search history when screen opens
    context.read<SearchBloc>().add(const LoadSearchHistory());
    
    return Scaffold(
      appBar: AppBar(title: const Text('Search Places'), elevation: 2),
      body: Column(
        children: [
          SearchInputField(
            onSearch: (query) {
              final locationState = context.read<LocationBloc>().state;
              Location? nearLocation;
              if (locationState is LocationTracking) {
                nearLocation = locationState.location;
              }
              context.read<SearchBloc>().add(
                SearchQuery(query: query, nearLocation: nearLocation),
              );
            },
            onClear: () => context.read<SearchBloc>().add(const ClearSearch()),
          ),
          SearchCategoryFilters(
            selectedCategory: null,
            onCategorySelected: (category) {
              // TODO: Implement category filtering in SearchBloc
            },
          ),
          Expanded(child: _buildContent(context)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return BlocBuilder<SearchBloc, SearchState>(
      builder: (context, state) {
        if (state is SearchSearching) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Searching...'),
              ],
            ),
          );
        }

        if (state is SearchResults) {
          if (state.isEmpty) {
            return const SearchEmptyState(query: '');
          }
          return ListView.builder(
            itemCount: state.results.length,
            itemBuilder: (context, index) {
              final result = state.results[index];
              return SearchResultItem(
                result: result,
                onTap: () => _showResultDetails(context, result),
              );
            },
          );
        }

        if (state is SearchError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Search Error',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.message,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        if (state is SearchHistoryLoaded) {
          return _buildRecentSearches(context, state.history);
        }

        return _buildRecentSearches(context, []);
      },
    );
  }

  Widget _buildRecentSearches(BuildContext context, List<String> history) {
    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.history,
                size: 80,
                color: Theme.of(context).colorScheme.primary.withAlpha(128),
              ),
              const SizedBox(height: 16),
              Text(
                'No recent searches',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Your search history will appear here',
                style: Theme.of(context).textTheme.bodyMedium,
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
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton(
                onPressed: () {
                  context.read<SearchBloc>().add(const ClearSearchHistory());
                },
                child: const Text('Clear All'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final query = history[index];
              return ListTile(
                leading: const Icon(Icons.history),
                title: Text(query),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    context.read<SearchBloc>().add(RemoveSearchHistoryItem(query));
                  },
                ),
                onTap: () {
                  final locationState = context.read<LocationBloc>().state;
                  Location? nearLocation;
                  if (locationState is LocationTracking) {
                    nearLocation = locationState.location;
                  }
                  context.read<SearchBloc>().add(
                    SearchQuery(query: query, nearLocation: nearLocation),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showResultDetails(BuildContext context, SearchResult result) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (result.address != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.address!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
            if (result.distanceMeters != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.directions_walk, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _formatDistance(result.distanceMeters!),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.pop(context);
                    context.read<MapCubit>().moveToLocation(result.location, zoom: 16);
                  },
                  icon: const Icon(Icons.map),
                  label: const Text('View on Map'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.pop(context);
                    final locationState = context.read<LocationBloc>().state;
                    if (locationState is LocationTracking) {
                      context.read<RouteBloc>().add(
                        CalculateRoute(
                          origin: locationState.location,
                          destination: result.location,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.navigation),
                  label: const Text('Navigate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDistance(double distanceMeters) {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    } else {
      final km = distanceMeters / 1000;
      return '${km.toStringAsFixed(1)} km';
    }
  }
}
