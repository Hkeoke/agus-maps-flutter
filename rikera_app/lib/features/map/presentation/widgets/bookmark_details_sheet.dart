import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rikera_app/core/theme/theme.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/presentation/blocs/blocs.dart';

/// Bottom sheet displaying bookmark details when marker is tapped.
///
/// Requirements: 16.10
class BookmarkDetailsSheet extends StatelessWidget {
  final Bookmark bookmark;

  const BookmarkDetailsSheet({
    super.key,
    required this.bookmark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getCategoryIcon(bookmark.category),
                color: _getCategoryColor(bookmark.category),
                size: 32,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bookmark.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      _getCategoryName(bookmark.category),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _getCategoryColor(bookmark.category),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Location: ${bookmark.location.latitude.toStringAsFixed(4)}, '
            '${bookmark.location.longitude.toStringAsFixed(4)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.read<MapCubit>().moveToLocation(
                        bookmark.location,
                        zoom: 16,
                      );
                },
                icon: const Icon(Icons.center_focus_strong),
                label: const Text('Center'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  final locationState = context.read<LocationBloc>().state;
                  if (locationState is LocationTracking) {
                    context.read<RouteBloc>().add(
                          CalculateRoute(
                            origin: locationState.location,
                            destination: bookmark.location,
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
    );
  }

  IconData _getCategoryIcon(BookmarkCategory category) {
    switch (category) {
      case BookmarkCategory.home:
        return Icons.home;
      case BookmarkCategory.work:
        return Icons.work;
      case BookmarkCategory.favorite:
        return Icons.star;
      case BookmarkCategory.other:
        return Icons.place;
    }
  }

  Color _getCategoryColor(BookmarkCategory category) {
    switch (category) {
      case BookmarkCategory.home:
        return Colors.blue;
      case BookmarkCategory.work:
        return Colors.orange;
      case BookmarkCategory.favorite:
        return Colors.red;
      case BookmarkCategory.other:
        return Colors.green;
    }
  }

  String _getCategoryName(BookmarkCategory category) {
    switch (category) {
      case BookmarkCategory.home:
        return 'Home';
      case BookmarkCategory.work:
        return 'Work';
      case BookmarkCategory.favorite:
        return 'Favorite';
      case BookmarkCategory.other:
        return 'Other';
    }
  }
}
