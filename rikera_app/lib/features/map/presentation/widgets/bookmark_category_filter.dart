import 'package:flutter/material.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';

/// Category filter dropdown for bookmarks.
///
/// Requirements: 16.9
class BookmarkCategoryFilter extends StatelessWidget {
  final BookmarkCategory? selectedCategory;
  final ValueChanged<BookmarkCategory?> onChanged;

  const BookmarkCategoryFilter({
    super.key,
    required this.selectedCategory,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: DropdownButton<BookmarkCategory?>(
        value: selectedCategory,
        hint: const Text('All Categories'),
        underline: const SizedBox.shrink(),
        items: [
          const DropdownMenuItem<BookmarkCategory?>(
            value: null,
            child: Text('All Categories'),
          ),
          ...BookmarkCategory.values.map((category) {
            return DropdownMenuItem<BookmarkCategory?>(
              value: category,
              child: Text(_getCategoryDisplayName(category)),
            );
          }),
        ],
        onChanged: onChanged,
      ),
    );
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
