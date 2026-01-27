import 'package:flutter/material.dart';

/// Empty state widget when no bookmarks exist.
class BookmarkEmptyState extends StatelessWidget {
  const BookmarkEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withAlpha(128),
          ),
          const SizedBox(height: 16),
          Text(
            'No bookmarks yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Add your favorite locations to quickly access them later',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
