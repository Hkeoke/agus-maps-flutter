import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/presentation/blocs/blocs.dart';
import 'package:rikera_app/features/map/presentation/widgets/widgets.dart';
import 'package:rikera_app/core/theme/theme.dart';

/// Screen for managing map downloads.
///
/// Requirements: 3.1, 3.8
class MapDownloadsScreen extends StatelessWidget {
  const MapDownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map Downloads'), elevation: 2),
      body: const _MapDownloadsBody(),
    );
  }
}

class _MapDownloadsBody extends StatefulWidget {
  const _MapDownloadsBody();

  @override
  State<_MapDownloadsBody> createState() => _MapDownloadsBodyState();
}

class _MapDownloadsBodyState extends State<_MapDownloadsBody> {
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
    context.read<MapDownloadBloc>().add(const LoadRegions());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MapDownloadBloc, MapDownloadState>(
      listener: _handleStateChanges,
      builder: (context, state) {
        if (state is MapDownloadInitial || state is MapDownloadLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is MapDownloadError) {
          return _MapDownloadsErrorView(
            message: state.message,
            onRetry: () => context.read<MapDownloadBloc>().add(const LoadRegions()),
          );
        }

        final regions = _getRegions(state);
        final totalStorage = _getTotalStorage(state);
        final query = _searchController.text.toLowerCase();
        final filteredRegions = query.isEmpty 
            ? regions 
            : regions.where((r) => r.name.toLowerCase().contains(query)).toList();

        return _MapDownloadsContent(
          regions: filteredRegions,
          totalStorage: totalStorage,
          state: state,
          searchController: _searchController,
          onSearchChanged: () => setState(() {}),
          onRefresh: () async {
            context.read<MapDownloadBloc>().add(const LoadRegions());
            await Future.delayed(const Duration(milliseconds: 500));
          },
          onDownload: (region) => _handleDownload(context, region),
          onDelete: (region) => _showDeleteConfirmation(context, region),
          onCancel: (regionId) => context.read<MapDownloadBloc>().add(CancelDownload(regionId)),
        );
      },
    );
  }

  void _handleStateChanges(BuildContext context, MapDownloadState state) {
    if (state is MapDownloadError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: Theme.of(context).colorScheme.error,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => context.read<MapDownloadBloc>().add(const LoadRegions()),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
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
  }

  void _handleDownload(BuildContext context, MapRegion region) {
    context.read<MapDownloadBloc>().add(DownloadRegion(region));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading ${region.name}...'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, MapRegion region) {
    showDialog(
      context: context,
      builder: (dialogContext) => DeleteRegionDialog(
        region: region,
        onConfirm: () {
          _lastDeletedRegionName = region.name;
          context.read<MapDownloadBloc>().add(DeleteRegion(region.id));
        },
      ),
    );
  }

  List<MapRegion> _getRegions(MapDownloadState state) {
    if (state is MapDownloadLoaded) return state.regions;
    if (state is MapDownloadDownloading) return state.regions;
    if (state is MapDownloadError) return state.regions;
    return [];
  }

  int _getTotalStorage(MapDownloadState state) {
    if (state is MapDownloadLoaded) return state.totalStorageUsed;
    if (state is MapDownloadDownloading) return state.totalStorageUsed;
    if (state is MapDownloadError) return state.totalStorageUsed;
    return 0;
  }
}

class _MapDownloadsContent extends StatelessWidget {
  final List<MapRegion> regions;
  final int totalStorage;
  final MapDownloadState state;
  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final Future<void> Function() onRefresh;
  final void Function(MapRegion) onDownload;
  final void Function(MapRegion) onDelete;
  final void Function(String) onCancel;

  const _MapDownloadsContent({
    required this.regions,
    required this.totalStorage,
    required this.state,
    required this.searchController,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.onDownload,
    required this.onDelete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final downloadedRegions = regions.where((r) => r.isDownloaded).toList();
    final availableRegions = regions.where((r) => !r.isDownloaded).toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: StorageHeader(totalStorageBytes: totalStorage)),
          SliverToBoxAdapter(child: _SearchBar(controller: searchController, onChanged: onSearchChanged)),
          if (downloadedRegions.isNotEmpty) ...[
            SliverToBoxAdapter(child: _SectionHeader(title: 'Downloaded Maps')),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => RegionListItem(
                  region: downloadedRegions[index],
                  state: state,
                  onDownload: () => onDownload(downloadedRegions[index]),
                  onDelete: () => onDelete(downloadedRegions[index]),
                  onCancel: () => onCancel(downloadedRegions[index].id),
                ),
                childCount: downloadedRegions.length,
              ),
            ),
          ],
          if (availableRegions.isNotEmpty) ...[
            SliverToBoxAdapter(child: _SectionHeader(title: 'Available Maps')),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => RegionListItem(
                  region: availableRegions[index],
                  state: state,
                  onDownload: () => onDownload(availableRegions[index]),
                  onDelete: () => onDelete(availableRegions[index]),
                  onCancel: () => onCancel(availableRegions[index].id),
                ),
                childCount: availableRegions.length,
              ),
            ),
          ],
          if (regions.isEmpty) const SliverFillRemaining(child: _EmptyState()),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: 'Search Country or Region',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        ),
        onChanged: (_) => onChanged(),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text('No maps available', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Pull down to refresh',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapDownloadsErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _MapDownloadsErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text('Failed to Load Maps', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(120, 48)),
            ),
          ],
        ),
      ),
    );
  }
}
