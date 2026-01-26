import 'package:flutter/material.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';

/// Widget that displays bookmark markers on the map.
///
/// This widget renders markers for all saved bookmarks with different
/// colors based on their category.
///
/// Requirements: 16.10
class BookmarkMarkersWidget extends StatelessWidget {
  final List<Bookmark> bookmarks;
  final Function(Bookmark) onBookmarkTap;

  const BookmarkMarkersWidget({
    super.key,
    required this.bookmarks,
    required this.onBookmarkTap,
  });

  @override
  Widget build(BuildContext context) {
    if (bookmarks.isEmpty) {
      return const SizedBox.shrink();
    }

    // For now, we'll display bookmark markers as positioned widgets
    // In a real implementation, these would be rendered by the map engine
    // This is a simplified overlay approach
    return Stack(
      children: bookmarks.map((bookmark) {
        return _buildBookmarkMarker(context, bookmark);
      }).toList(),
    );
  }

  /// Builds a single bookmark marker.
  ///
  /// Different marker colors are used for different categories.
  Widget _buildBookmarkMarker(BuildContext context, Bookmark bookmark) {
    return Positioned(
      // Note: In a real implementation, these positions would be calculated
      // based on the bookmark's lat/lon and the current map view
      // For now, this is a placeholder that shows the concept
      left: 100,
      top: 100,
      child: GestureDetector(
        onTap: () => onBookmarkTap(bookmark),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Marker icon with category color
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getCategoryColor(bookmark.category),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                _getCategoryIcon(bookmark.category),
                color: Colors.white,
                size: 24,
              ),
            ),
            // Marker pin
            CustomPaint(
              size: const Size(10, 10),
              painter: _MarkerPinPainter(
                color: _getCategoryColor(bookmark.category),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Gets the icon for a bookmark category.
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

  /// Gets the color for a bookmark category.
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
}

/// Custom painter for the marker pin (triangle pointing down).
class _MarkerPinPainter extends CustomPainter {
  final Color color;

  _MarkerPinPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, size.height) // Bottom point
      ..lineTo(0, 0) // Top left
      ..lineTo(size.width, 0) // Top right
      ..close();

    canvas.drawPath(path, paint);

    // Add white border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(_MarkerPinPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
