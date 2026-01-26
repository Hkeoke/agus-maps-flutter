import 'package:flutter/material.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';

/// Widget displaying ETA and remaining distance.
///
/// Shows:
/// - Estimated time of arrival
/// - Remaining distance
/// - Updates in real-time
///
/// Requirements: 5.3
class EtaDisplayWidget extends StatelessWidget {
  final NavigationState navigationState;

  const EtaDisplayWidget({super.key, required this.navigationState});

  @override
  Widget build(BuildContext context) {
    final eta = _calculateEta();
    final distance = _formatDistance(navigationState.remainingDistanceMeters);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // ETA display
          _buildInfoCard(icon: Icons.access_time, label: 'ETA', value: eta),

          // Vertical divider
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withValues(alpha: 0.3),
          ),

          // Distance display
          _buildInfoCard(
            icon: Icons.straighten,
            label: 'Distance',
            value: distance,
          ),
        ],
      ),
    );
  }

  /// Builds an info card with icon, label, and value.
  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.8)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Calculates and formats the ETA.
  ///
  /// Returns time in format "HH:MM" or "MM min" depending on duration.
  String _calculateEta() {
    final now = DateTime.now();
    final eta = now.add(
      Duration(seconds: navigationState.remainingTimeSeconds),
    );

    // If less than 60 minutes, show minutes
    if (navigationState.remainingTimeSeconds < 3600) {
      final minutes = (navigationState.remainingTimeSeconds / 60).ceil();
      return '$minutes min';
    }

    // Otherwise show time
    final hour = eta.hour.toString().padLeft(2, '0');
    final minute = eta.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Formats distance in a human-readable way.
  ///
  /// Shows meters for distances < 1000m, kilometers otherwise.
  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      final km = meters / 1000;
      if (km < 10) {
        return '${km.toStringAsFixed(1)} km';
      } else {
        return '${km.round()} km';
      }
    }
  }
}
