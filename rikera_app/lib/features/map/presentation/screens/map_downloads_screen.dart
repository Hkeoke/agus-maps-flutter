import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/domain/repositories/repositories.dart';
import 'package:rikera_app/features/map/presentation/blocs/blocs.dart';

/// Screen for managing map downloads.
///
/// This screen displays:
/// - Total storage usage at the top
/// - List of downloaded regions
/// - List of available regions for download
///
/// Requirements: 3.1, 3.8
class MapDownloadsScreen extends StatefulWidget {
  const MapDownloadsScreen({super.key});

  @override
  State<MapDownloadsScreen> createState() => _MapDownloadsScreenState();
}

class _MapDownloadsScreenState extends State<MapDownloadsScreen> {
  String? _lastDeletedRegionName;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Load regions when screen is first displayed
    context.read<MapDownloadBloc>().add(const LoadRegions());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map Downloads'), elevation: 2),
      body: BlocConsumer<MapDownloadBloc, MapDownloadState>(
        listener: (context, state) {
          // Show error snackbar when download or delete fails
          if (state is MapDownloadError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: () {
                    context.read<MapDownloadBloc>().add(const LoadRegions());
                  },
                ),
                duration: const Duration(seconds: 5),
              ),
            );
          }

          // Show success message when deletion completes
          // Requirements: 3.7, 3.8
          if (state is MapDownloadLoaded && _lastDeletedRegionName != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$_lastDeletedRegionName deleted successfully'),
                backgroundColor: Theme.of(context).colorScheme.primary,
                duration: const Duration(seconds: 2),
              ),
            );
            _lastDeletedRegionName = null;
          }
        },
        builder: (context, state) {
          if (state is MapDownloadInitial || state is MapDownloadLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is MapDownloadError) {
            return _buildErrorView(context, state);
          }

          // Handle both loaded and downloading states
          final regions = _getRegions(state);
          final totalStorage = _getTotalStorage(state);
          
          final query = _searchController.text.toLowerCase();
          final filteredRegions = query.isEmpty 
              ? regions 
              : regions.where((r) => r.name.toLowerCase().contains(query)).toList();

          final downloadedRegions = filteredRegions
              .where((r) => r.isDownloaded)
              .toList();
          final availableRegions = filteredRegions
              .where((r) => !r.isDownloaded)
              .toList();

          return RefreshIndicator(
            onRefresh: () async {
              context.read<MapDownloadBloc>().add(const LoadRegions());
              // Wait a bit for the bloc to process
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: CustomScrollView(
              slivers: [
                // Storage usage header
                SliverToBoxAdapter(child: _buildStorageHeader(totalStorage)),

                // Search Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search Country or Region',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
                ),

                // Downloaded regions section
                if (downloadedRegions.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _buildSectionHeader('Downloaded Maps'),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return _buildRegionListItem(
                        context,
                        downloadedRegions[index],
                        state,
                      );
                    }, childCount: downloadedRegions.length),
                  ),
                ],

                // Available regions section
                if (availableRegions.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _buildSectionHeader('Available Maps'),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return _buildRegionListItem(
                        context,
                        availableRegions[index],
                        state,
                      );
                    }, childCount: availableRegions.length),
                  ),
                ],

                // Empty state
                if (regions.isEmpty) ...[
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.map_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No maps available',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pull down to refresh',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// Builds the storage usage header at the top of the screen.
  ///
  /// Requirements: 3.8
  Widget _buildStorageHeader(int totalStorageBytes) {
    final storageMB = (totalStorageBytes / (1024 * 1024)).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.storage,
            size: 32,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Storage Used',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$storageMB MB',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a section header (e.g., "Downloaded Maps", "Available Maps").
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  /// Builds a region list item with download/delete actions.
  ///
  /// Requirements: 3.2, 3.3, 3.5, 3.7
  Widget _buildRegionListItem(
    BuildContext context,
    MapRegion region,
    MapDownloadState state,
  ) {
    final isDownloading =
        state is MapDownloadDownloading && state.region.id == region.id;
    final downloadProgress = isDownloading ? state.progress : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            // Region name
            title: Text(
              region.name,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            // Region size
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _formatSize(region.sizeBytes),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
            // Download/Delete button
            trailing: _buildRegionAction(context, region, isDownloading),
          ),

          // Progress bar for active downloads
          if (isDownloading && downloadProgress != null)
            _buildProgressBar(context, downloadProgress),
        ],
      ),
    );
  }

  /// Builds the action button for a region (download or delete).
  ///
  /// Requirements: 3.2, 3.3, 13.1
  Widget _buildRegionAction(
    BuildContext context,
    MapRegion region,
    bool isDownloading,
  ) {
    if (isDownloading) {
      // Show cancel button during download
      return IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Cancel Download',
        iconSize: 28,
        onPressed: () {
          context.read<MapDownloadBloc>().add(CancelDownload(region.id));
        },
      );
    } else if (region.isDownloaded) {
      // Show delete button for downloaded regions
      return IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Delete Map',
        iconSize: 28,
        color: Theme.of(context).colorScheme.error,
        onPressed: () {
          _showDeleteConfirmation(context, region);
        },
      );
    } else {
      // Show download button for available regions
      return IconButton(
        icon: const Icon(Icons.download),
        tooltip: 'Download Map',
        iconSize: 28,
        color: Theme.of(context).colorScheme.primary,
        onPressed: () {
          _handleDownload(context, region);
        },
      );
    }
  }

  /// Handles the download action for a region.
  ///
  /// This method initiates the download and handles any errors that occur.
  /// If the download fails, the user can retry by tapping the download button again.
  ///
  /// Requirements: 3.2, 3.3, 13.1
  void _handleDownload(BuildContext context, MapRegion region) {
    // Initiate the download
    context.read<MapDownloadBloc>().add(DownloadRegion(region));

    // Show a snackbar to indicate download started
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading ${region.name}...'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Builds a progress bar for an active download.
  ///
  /// Requirements: 3.3, 3.5
  Widget _buildProgressBar(BuildContext context, DownloadProgress progress) {
    final progressPercent = (progress.progress * 100).toStringAsFixed(0);
    final receivedMB = (progress.bytesReceived / (1024 * 1024)).toStringAsFixed(
      1,
    );
    final totalMB = (progress.totalBytes / (1024 * 1024)).toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.progress,
              minHeight: 8,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Progress text
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$receivedMB MB / $totalMB MB',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              Text(
                '$progressPercent%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Shows a confirmation dialog before deleting a region.
  ///
  /// Requirements: 3.7, 3.8
  void _showDeleteConfirmation(BuildContext context, MapRegion region) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Map'),
        content: Text(
          'Are you sure you want to delete ${region.name}? '
          'This will free up ${_formatSize(region.sizeBytes)} of storage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(
              minimumSize: const Size(80, 48), // Large touch target
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // Store the region name for success message
              _lastDeletedRegionName = region.name;
              // Trigger deletion
              context.read<MapDownloadBloc>().add(DeleteRegion(region.id));
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              minimumSize: const Size(80, 48), // Large touch target
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Builds the error view when loading fails.
  Widget _buildErrorView(BuildContext context, MapDownloadError state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
              'Failed to Load Maps',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              state.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                context.read<MapDownloadBloc>().add(const LoadRegions());
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(120, 48), // Large touch target
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper to get regions from any state that contains them.
  List<MapRegion> _getRegions(MapDownloadState state) {
    if (state is MapDownloadLoaded) {
      return state.regions;
    } else if (state is MapDownloadDownloading) {
      return state.regions;
    } else if (state is MapDownloadError) {
      return state.regions;
    }
    return [];
  }

  /// Helper to get total storage from any state that contains it.
  int _getTotalStorage(MapDownloadState state) {
    if (state is MapDownloadLoaded) {
      return state.totalStorageUsed;
    } else if (state is MapDownloadDownloading) {
      return state.totalStorageUsed;
    } else if (state is MapDownloadError) {
      return state.totalStorageUsed;
    }
    return 0;
  }

  /// Formats a byte size into a human-readable string.
  String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}
