import 'package:flutter/material.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart'
    hide
        Route; // Hide Route from entities to avoid conflict with Flutter's Route
import 'package:rikera_app/features/map/domain/entities/route.dart' as entities;

/// Custom painter for drawing route overlays on the map.
///
/// This painter draws:
/// - Route polyline connecting waypoints
/// - Highlighted current segment
/// - Turn markers at segment transitions
///
/// Requirements: 5.2
class RouteOverlayPainter extends CustomPainter {
  final entities.Route route;
  final RouteSegment? currentSegment;
  final Color routeColor;
  final Color currentSegmentColor;
  final double strokeWidth;

  RouteOverlayPainter({
    required this.route,
    this.currentSegment,
    this.routeColor = Colors.blue,
    this.currentSegmentColor = Colors.green,
    this.strokeWidth = 8.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw route polyline
    _drawRoutePolyline(canvas, size);

    // Draw turn markers
    _drawTurnMarkers(canvas, size);
  }

  /// Draws the route polyline connecting all waypoints.
  void _drawRoutePolyline(Canvas canvas, Size size) {
    if (route.waypoints.isEmpty) return;

    final paint = Paint()
      ..color = routeColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final currentSegmentPaint = Paint()
      ..color = currentSegmentColor
      ..strokeWidth = strokeWidth + 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Draw each segment
    for (int i = 0; i < route.segments.length; i++) {
      final segment = route.segments[i];
      final isCurrentSegment =
          currentSegment != null &&
          segment.start.latitude == currentSegment!.start.latitude &&
          segment.start.longitude == currentSegment!.start.longitude;

      // Convert lat/lon to screen coordinates (simplified - in real app would use map projection)
      final startPoint = _latLonToScreen(segment.start, size);
      final endPoint = _latLonToScreen(segment.end, size);

      canvas.drawLine(
        startPoint,
        endPoint,
        isCurrentSegment ? currentSegmentPaint : paint,
      );
    }
  }

  /// Draws turn markers at segment transitions.
  void _drawTurnMarkers(Canvas canvas, Size size) {
    for (final segment in route.segments) {
      if (segment.turnDirection != TurnDirection.straight) {
        final point = _latLonToScreen(segment.start, size);

        // Draw turn marker circle
        final markerPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;

        canvas.drawCircle(point, 12, markerPaint);

        // Draw turn icon (simplified)
        final iconPaint = Paint()
          ..color = _getTurnColor(segment.turnDirection)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(point, 8, iconPaint);
      }
    }
  }

  /// Converts lat/lon coordinates to screen coordinates.
  ///
  /// Note: This is a simplified implementation. In a real app, this would
  /// use the map's projection system to accurately convert coordinates.
  Offset _latLonToScreen(Location location, Size size) {
    // Simplified conversion - assumes route fits in screen bounds
    // In real implementation, would use map bounds and projection
    final bounds = route.bounds;
    final latRange = bounds.maxLatitude - bounds.minLatitude;
    final lonRange = bounds.maxLongitude - bounds.minLongitude;

    final x =
        ((location.longitude - bounds.minLongitude) / lonRange) * size.width;
    final y =
        ((bounds.maxLatitude - location.latitude) / latRange) * size.height;

    return Offset(x, y);
  }

  /// Gets the color for a turn direction.
  Color _getTurnColor(TurnDirection direction) {
    switch (direction) {
      case TurnDirection.left:
      case TurnDirection.sharpLeft:
        return Colors.orange;
      case TurnDirection.right:
      case TurnDirection.sharpRight:
        return Colors.orange;
      case TurnDirection.uTurnLeft:
      case TurnDirection.uTurnRight:
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  @override
  bool shouldRepaint(RouteOverlayPainter oldDelegate) {
    return oldDelegate.route != route ||
        oldDelegate.currentSegment != currentSegment;
  }
}

/// Widget that displays the route overlay.
///
/// Requirements: 5.2
class RouteOverlayWidget extends StatelessWidget {
  final entities.Route route;
  final RouteSegment? currentSegment;

  const RouteOverlayWidget({
    super.key,
    required this.route,
    this.currentSegment,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: RouteOverlayPainter(
        route: route,
        currentSegment: currentSegment,
      ),
      child: Container(),
    );
  }
}
