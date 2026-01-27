import 'package:flutter/material.dart';
import 'package:rikera_app/core/theme/theme.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';

/// List item widget for displaying a search result.
///
/// Requirements: 7.2, 9.1
class SearchResultItem extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;

  const SearchResultItem({
    super.key,
    required this.result,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            _buildIcon(context),
            const SizedBox(width: 16),
            Expanded(child: _buildDetails(context)),
            if (result.distanceMeters != null) _buildDistance(context),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        _getTypeIcon(result.type),
        color: Theme.of(context).colorScheme.primary,
        size: 28,
      ),
    );
  }

  Widget _buildDetails(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          result.name,
          style: Theme.of(context).textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (result.address != null) ...[
          const SizedBox(height: 4),
          Text(
            result.address!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 4),
        Text(
          _getTypeName(result.type),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ],
    );
  }

  Widget _buildDistance(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _formatDistance(result.distanceMeters!),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  IconData _getTypeIcon(SearchResultType type) {
    switch (type) {
      case SearchResultType.poi:
        return Icons.place;
      case SearchResultType.address:
        return Icons.location_on;
      case SearchResultType.city:
        return Icons.location_city;
      case SearchResultType.region:
        return Icons.map;
      case SearchResultType.country:
        return Icons.public;
      case SearchResultType.other:
        return Icons.help_outline;
    }
  }

  String _getTypeName(SearchResultType type) {
    switch (type) {
      case SearchResultType.poi:
        return 'Point of Interest';
      case SearchResultType.address:
        return 'Address';
      case SearchResultType.city:
        return 'City';
      case SearchResultType.region:
        return 'Region';
      case SearchResultType.country:
        return 'Country';
      case SearchResultType.other:
        return 'Other';
    }
  }

  String _formatDistance(double distanceMeters) {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    } else {
      final km = distanceMeters / 1000;
      return '${km.toStringAsFixed(1)} km';
    }
  }
}
