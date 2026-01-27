import 'package:flutter/material.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';

/// Dialog for adding a new bookmark.
///
/// Requirements: 16.2
class AddBookmarkDialog extends StatefulWidget {
  final Location? currentLocation;
  final Function(Bookmark) onSave;

  const AddBookmarkDialog({
    super.key,
    this.currentLocation,
    required this.onSave,
  });

  @override
  State<AddBookmarkDialog> createState() => _AddBookmarkDialogState();
}

class _AddBookmarkDialogState extends State<AddBookmarkDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _latController;
  late final TextEditingController _lonController;
  BookmarkCategory _selectedCategory = BookmarkCategory.favorite;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _latController = TextEditingController();
    _lonController = TextEditingController();

    // Pre-fill with current location if available
    if (widget.currentLocation != null) {
      _latController.text =
          widget.currentLocation!.latitude.toStringAsFixed(6);
      _lonController.text =
          widget.currentLocation!.longitude.toStringAsFixed(6);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Bookmark'),
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
            TextField(
              controller: _latController,
              decoration: const InputDecoration(
                labelText: 'Latitude',
                hintText: 'Enter latitude',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _lonController,
              decoration: const InputDecoration(
                labelText: 'Longitude',
                hintText: 'Enter longitude',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
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
          child: const Text('Add'),
        ),
      ],
    );
  }

  void _handleSave() {
    final name = _nameController.text.trim();
    final latText = _latController.text.trim();
    final lonText = _lonController.text.trim();

    if (name.isEmpty || latText.isEmpty || lonText.isEmpty) {
      _showError('Please fill all fields');
      return;
    }

    final lat = double.tryParse(latText);
    final lon = double.tryParse(lonText);

    if (lat == null || lon == null) {
      _showError('Invalid latitude or longitude');
      return;
    }

    final bookmark = Bookmark(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      location: Location(
        latitude: lat,
        longitude: lon,
        timestamp: DateTime.now(),
      ),
      category: _selectedCategory,
      createdAt: DateTime.now(),
    );

    widget.onSave(bookmark);
    Navigator.of(context).pop();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
