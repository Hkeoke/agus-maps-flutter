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
    final arrivalTime = _calculateArrivalTime();
    final duration = _formatDuration(navigationState.remainingTimeSeconds);
    final distance = _formatDistance(navigationState.remainingDistanceMeters);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Duration display
        _buildInfoCard(
          icon: Icons.timer,
          label: 'Duration',
          value: duration,
          valueColor: Colors.greenAccent,
        ),

        // Vertical divider
        _buildDivider(),

        // Arrival Time display
        _buildInfoCard(
          icon: Icons.access_time,
          label: 'Arrival',
          value: arrivalTime,
        ),

        // Vertical divider
        _buildDivider(),

        // Distance display
        _buildInfoCard(
          icon: Icons.straighten,
          label: 'Distance',
          value: distance,
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 30,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

  /// Builds an info card with icon, label, and value.
  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    Color valueColor = Colors.white,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Calculates and formats the Arrival Time.
  String _calculateArrivalTime() {
    final now = DateTime.now();
    final eta = now.add(
      Duration(seconds: navigationState.remainingTimeSeconds),
    );

    final hour = eta.hour.toString().padLeft(2, '0');
    final minute = eta.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Formats duration (remaining time) in a human-readable way.
  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '$seconds s';
    }
    final minutes = (seconds / 60).floor();
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = (minutes / 60).floor();
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}m';
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
