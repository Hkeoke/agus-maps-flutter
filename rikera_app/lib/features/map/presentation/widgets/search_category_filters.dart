import 'package:flutter/material.dart';
import 'package:rikera_app/features/map/domain/repositories/search_repository.dart';
import 'package:rikera_app/core/theme/theme.dart';

/// Category filter chips for search.
///
/// Requirements: 7.4, 9.1
class SearchCategoryFilters extends StatelessWidget {
  final SearchCategory? selectedCategory;
  final ValueChanged<SearchCategory?> onCategorySelected;

  const SearchCategoryFilters({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildCategoryChip(context, 'All', null),
          _buildCategoryChip(context, 'Restaurant', SearchCategory.restaurant),
          _buildCategoryChip(context, 'Shopping', SearchCategory.shopping),
          _buildCategoryChip(context, 'Gas', SearchCategory.gasStation),
          _buildCategoryChip(context, 'Parking', SearchCategory.parking),
          _buildCategoryChip(context, 'Hotel', SearchCategory.hotel),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(
    BuildContext context,
    String label,
    SearchCategory? category,
  ) {
    final isSelected = selectedCategory == category;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          onCategorySelected(selected ? category : null);
        },
        selectedColor: Theme.of(context).colorScheme.primary,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        labelPadding: EdgeInsets.zero,
      ),
    );
  }
}
