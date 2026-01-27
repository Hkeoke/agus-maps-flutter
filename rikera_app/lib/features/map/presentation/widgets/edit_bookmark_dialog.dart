import 'package:flutter/material.dart';
import 'package:rikera_app/core/theme/theme.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';

/// Dialog for editing an existing bookmark.
///
/// Requirements: 16.6, 16.7
class EditBookmarkDialog extends StatefulWidget {
  final Bookmark bookmark;
  final Function(Bookmark) onSave;

  const EditBookmarkDialog({
    super.key,
    required this.bookmark,
    required this.onSave,
  });

  @override
  State<EditBookmarkDialog> createState() => _EditBookmarkDialogState();
}

class _EditBookmarkDialogState extends State<EditBookmarkDialog> {
  late final TextEditingController _nameController;
  late BookmarkCategory _selectedCategory;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.bookmark.name);
    _selectedCategory = widget.bookmark.category;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Bookmark'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Enter bookmark name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<BookmarkCategory>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: BookmarkCategory.values.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Row(
                    children: [
                      Icon(
                        _getCategoryIcon(category),
                        color: _getCategoryColor(category),
                      ),
                      const SizedBox(width: 8),
                      Text(_getCategoryDisplayName(category)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (category) {
                if (category != null) {
                  setState(() => _selectedCategory = category);
                }
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Location (cannot be changed):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lat: ${widget.bookmark.location.latitude.toStringAsFixed(6)}',
                  ),
                  Text(
                    'Lon: ${widget.bookmark.location.longitude.toStringAsFixed(6)}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _handleSave,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _handleSave() {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    final updatedBookmark = widget.bookmark.copyWith(
      name: name,
      category: _selectedCategory,
    );

    widget.onSave(updatedBookmark);
    Navigator.of(context).pop();
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
