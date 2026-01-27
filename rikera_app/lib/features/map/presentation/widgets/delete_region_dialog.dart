import 'package:flutter/material.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';

/// Confirmation dialog for deleting a map region.
///
/// Requirements: 3.7, 3.8
class DeleteRegionDialog extends StatelessWidget {
  final MapRegion region;
  final VoidCallback onConfirm;

  const DeleteRegionDialog({
    super.key,
    required this.region,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Map'),
      content: Text(
        'Are you sure you want to delete ${region.name}? '
        'This will free up ${_formatSize(region.sizeBytes)} of storage.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            minimumSize: const Size(80, 48),
          ),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            minimumSize: const Size(80, 48),
          ),
          child: const Text('Delete'),
        ),
      ],
    );
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
