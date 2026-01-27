import 'package:flutter/material.dart';
import 'package:rikera_app/core/theme/theme.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';

/// List item widget for displaying a bookmark.
///
/// Requirements: 16.3, 16.4, 9.1
class BookmarkListItem extends StatelessWidget {
  final Bookmark bookmark;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onNavigate;
  final VoidCallback onDelete;

  const BookmarkListItem({
    super.key,
    required this.bookmark,
    required this.onTap,
    required this.onEdit,
    required this.onNavigate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(bookmark.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white, size: 32),
      ),
      confirmDismiss: (direction) => _showDeleteConfirmation(context),
      onDismissed: (direction) => onDelete(),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                _buildCategoryIcon(),
                const SizedBox(width: 16),
                Expanded(child: _buildBookmarkDetails(context)),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _getCategoryColor(bookmark.category).withAlpha(51),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        _getCategoryIcon(bookmark.category),
        color: _getCategoryColor(bookmark.category),
        size: 28,
      ),
    );
  }

  Widget _buildBookmarkDetails(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          bookmark.name,
          style: Theme.of(context).textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          _getCategoryDisplayName(bookmark.category),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _getCategoryColor(bookmark.category),
              ),
        ),
        const SizedBox(height: 4),
        Text(
          '${bookmark.location.latitude.toStringAsFixed(4)}, '
          '${bookmark.location.longitude.toStringAsFixed(4)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.edit),
          iconSize: 24,
          tooltip: 'Edit',
          onPressed: onEdit,
        ),
        IconButton(
          icon: const Icon(Icons.navigation),
          iconSize: 24,
          tooltip: 'Navigate',
          onPressed: onNavigate,
        ),
      ],
    );
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bookmark'),
        content: Text('Are you sure you want to delete "${bookmark.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
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

  String _getCategoryDisplayName(BookmarkCategory category) {
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
