import 'package:flutter/material.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/core/theme/theme.dart';

/// Widget displaying turn-by-turn navigation instructions.
///
/// Shows:
/// - Large turn arrow icon
/// - Distance to turn (large font)
/// - Next turn preview (smaller)
/// - Street name display
///
/// Requirements: 6.2, 9.2
class TurnInstructionWidget extends StatelessWidget {
  final NavigationState navigationState;

  const TurnInstructionWidget({super.key, required this.navigationState});

  @override
  Widget build(BuildContext context) {
    final turnDirection = navigationState.turnDirection ?? TurnDirection.straight;
    final nextStreetName = navigationState.nextStreetName;
    final currentStreetName = navigationState.currentStreetName;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Large turn arrow icon
          Icon(
            _getTurnIcon(turnDirection),
            size: 64,
            color: Colors.white,
          ),

          const SizedBox(width: 20),

          // Turn information
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Distance to turn (large font)
                Text(
                  _formatDistance(navigationState.distanceToNextTurnMeters),
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),

                const SizedBox(height: 2),

                // Street name (Next street if turning, current if straight)
                Text(
                  nextStreetName ?? currentStreetName ?? 'Sigue recto',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a "continue straight" display when no turn is upcoming.
  Widget _buildContinueStraight(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.arrow_upward,
              size: 56,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDistance(navigationState.remainingDistanceMeters),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Continue straight',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Gets the appropriate icon for a turn direction.
  IconData _getTurnIcon(TurnDirection direction) {
    switch (direction) {
      case TurnDirection.straight:
        return Icons.navigation;
      case TurnDirection.slightLeft:
        return Icons.turn_slight_left;
      case TurnDirection.left:
        return Icons.turn_left;
      case TurnDirection.sharpLeft:
        return Icons.turn_sharp_left;
      case TurnDirection.uTurnLeft:
        return Icons.u_turn_left;
      case TurnDirection.slightRight:
        return Icons.turn_slight_right;
      case TurnDirection.right:
        return Icons.turn_right;
      case TurnDirection.sharpRight:
        return Icons.turn_sharp_right;
      case TurnDirection.uTurnRight:
        return Icons.u_turn_right;
      case TurnDirection.roundabout:
        return Icons.roundabout_left;
      case TurnDirection.exitRoundabout:
        return Icons.roundabout_right;
      case TurnDirection.destination:
        return Icons.flag;
    }
  }

  /// Gets human-readable text for a turn direction.
  String _getTurnDirectionText(TurnDirection direction) {
    switch (direction) {
      case TurnDirection.straight:
        return 'Continue straight';
      case TurnDirection.slightLeft:
        return 'Keep left';
      case TurnDirection.left:
        return 'Turn left';
      case TurnDirection.sharpLeft:
        return 'Sharp left';
      case TurnDirection.uTurnLeft:
        return 'U-turn left';
      case TurnDirection.slightRight:
        return 'Keep right';
      case TurnDirection.right:
        return 'Turn right';
      case TurnDirection.sharpRight:
        return 'Sharp right';
      case TurnDirection.uTurnRight:
        return 'U-turn right';
      case TurnDirection.roundabout:
        return 'Enter roundabout';
      case TurnDirection.exitRoundabout:
        return 'Exit roundabout';
      case TurnDirection.destination:
        return 'Arrive at destination';
    }
  }

  /// Formats distance in a human-readable way.
  ///
  /// Shows meters for distances < 1000m, kilometers otherwise.
  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      final km = meters / 1000;
      return '${km.toStringAsFixed(1)} km';
    }
  }
}
