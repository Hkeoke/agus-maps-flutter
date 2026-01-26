import 'package:flutter/material.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/core/constants/app_constants.dart';

/// Widget displaying current speed and speed limit.
///
/// Shows:
/// - Current speed from GPS (large, prominent)
/// - Speed limit from map data
/// - Warning highlight when exceeding limit
/// - Support for km/h and mph units
///
/// Requirements: 6.6, 15.1, 15.2, 15.3, 15.4, 15.5
class SpeedDisplayWidget extends StatelessWidget {
  final NavigationState navigationState;
  final SpeedUnit speedUnit;

  const SpeedDisplayWidget({
    super.key,
    required this.navigationState,
    this.speedUnit = SpeedUnit.kmh,
  });

  @override
  Widget build(BuildContext context) {
    final currentSpeed = navigationState.currentLocation.speed ?? 0.0;
    final speedLimitKmh = navigationState.currentSegment?.speedLimitKmh;

    // Convert m/s to km/h
    final currentSpeedKmh = currentSpeed * 3.6;

    // Convert to user's preferred unit
    final displaySpeed = speedUnit == SpeedUnit.kmh
        ? currentSpeedKmh
        : currentSpeedKmh * AppConstants.kmhToMphFactor;

    final displaySpeedLimit = speedLimitKmh != null
        ? (speedUnit == SpeedUnit.kmh
              ? speedLimitKmh.toDouble()
              : speedLimitKmh * AppConstants.kmhToMphFactor)
        : null;

    // Check if exceeding speed limit
    final isExceedingLimit =
        speedLimitKmh != null &&
        currentSpeedKmh >
            speedLimitKmh * AppConstants.speedLimitWarningThreshold;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Current speed display
        _buildCurrentSpeed(displaySpeed, isExceedingLimit),

        // Speed limit display (if available)
        if (displaySpeedLimit != null) ...[
          const SizedBox(width: 24),
          _buildSpeedLimit(displaySpeedLimit, isExceedingLimit),
        ],
      ],
    );
  }

  /// Builds the current speed display.
  ///
  /// Large, prominent display with warning color when exceeding limit.
  ///
  /// Requirements: 15.2, 15.3, 15.4
  Widget _buildCurrentSpeed(double speed, bool isExceeding) {
    return Column(
      children: [
        Text(
          speed.round().toString(),
          style: TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.bold,
            color: isExceeding ? Colors.red : Colors.white,
            height: 1.0,
          ),
        ),
        Text(
          speedUnit.displayName,
          style: TextStyle(
            fontSize: 16,
            color: isExceeding
                ? Colors.red.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Current',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  /// Builds the speed limit display.
  ///
  /// Shows speed limit with warning highlight when exceeded.
  /// Only displayed when speed limit data is available.
  ///
  /// Requirements: 15.1, 15.3, 15.5
  Widget _buildSpeedLimit(double speedLimit, bool isExceeding) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isExceeding ? Colors.red : Colors.white,
        border: Border.all(
          color: isExceeding ? Colors.red.shade900 : Colors.red,
          width: 4,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            speedLimit.round().toString(),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: isExceeding ? Colors.white : Colors.black,
              height: 1.0,
            ),
          ),
          Text(
            speedUnit.displayName,
            style: TextStyle(
              fontSize: 10,
              color: isExceeding
                  ? Colors.white.withValues(alpha: 0.8)
                  : Colors.black.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
