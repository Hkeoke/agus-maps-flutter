import 'package:flutter/material.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/domain/repositories/map_repository.dart';
import 'package:rikera_app/features/map/presentation/blocs/blocs.dart';

/// Region list item widget with download/delete actions.
///
/// Requirements: 3.2, 3.3, 3.5, 3.7
class RegionListItem extends StatelessWidget {
  final MapRegion region;
  final MapDownloadState state;
  final VoidCallback onDownload;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  const RegionListItem({
    super.key,
    required this.region,
    required this.state,
    required this.onDownload,
    required this.onDelete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isDownloading = state is MapDownloadDownloading && 
        (state as MapDownloadDownloading).region.id == region.id;
    final downloadProgress = isDownloading 
        ? (state as MapDownloadDownloading).progress 
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            title: Text(
              region.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _formatSize(region.sizeBytes),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
            trailing: _buildActionButton(context, isDownloading),
          ),
          if (isDownloading && downloadProgress != null)
            _DownloadProgressBar(progress: downloadProgress),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, bool isDownloading) {
    if (isDownloading) {
      return IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Cancel Download',
        iconSize: 28,
        onPressed: onCancel,
      );
    } else if (region.isDownloaded) {
      return IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Delete Map',
        iconSize: 28,
        color: Theme.of(context).colorScheme.error,
        onPressed: onDelete,
      );
    } else {
      return IconButton(
        icon: const Icon(Icons.download),
        tooltip: 'Download Map',
        iconSize: 28,
        color: Theme.of(context).colorScheme.primary,
        onPressed: onDownload,
      );
    }
  }

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

/// Download progress bar widget.
///
/// Requirements: 3.3, 3.5
class _DownloadProgressBar extends StatelessWidget {
  final DownloadProgress progress;

  const _DownloadProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    final progressPercent = (progress.progress * 100).toStringAsFixed(0);
    final receivedMB = (progress.bytesReceived / (1024 * 1024)).toStringAsFixed(1);
    final totalMB = (progress.totalBytes / (1024 * 1024)).toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.progress,
              minHeight: 8,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 4),
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
}
