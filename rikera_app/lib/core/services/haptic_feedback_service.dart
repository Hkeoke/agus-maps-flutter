import 'package:flutter/services.dart';
import 'package:rikera_app/core/utils/logger.dart';

/// Service for providing haptic feedback during navigation.
///
/// This service provides tactile feedback for important navigation events:
/// - Turn approach warnings
/// - Off-route detection
/// - Arrival at destination
///
/// Requirements: 6.2, 6.5, 6.7
class HapticFeedbackService {
  final AppLogger _logger = const AppLogger('HapticFeedbackService');

  /// Provides haptic feedback when approaching a turn.
  ///
  /// Uses a medium impact vibration to alert the driver.
  ///
  /// Requirements: 6.2
  Future<void> vibrateTurnApproach() async {
    try {
      await HapticFeedback.mediumImpact();
      _logger.debug('Haptic feedback: turn approach');
    } catch (e) {
      _logger.error(
        'Failed to provide turn approach haptic feedback',
        error: e,
      );
    }
  }

  /// Provides haptic feedback when going off-route.
  ///
  /// Uses a heavy impact vibration to alert the driver of the deviation.
  ///
  /// Requirements: 6.5
  Future<void> vibrateOffRoute() async {
    try {
      await HapticFeedback.heavyImpact();
      _logger.debug('Haptic feedback: off-route');
    } catch (e) {
      _logger.error('Failed to provide off-route haptic feedback', error: e);
    }
  }

  /// Provides haptic feedback when arriving at destination.
  ///
  /// Uses a light impact vibration to confirm arrival.
  ///
  /// Requirements: 6.7
  Future<void> vibrateArrival() async {
    try {
      await HapticFeedback.lightImpact();
      _logger.debug('Haptic feedback: arrival');
    } catch (e) {
      _logger.error('Failed to provide arrival haptic feedback', error: e);
    }
  }

  /// Provides a selection haptic feedback.
  ///
  /// Used for general UI interactions like button presses.
  Future<void> vibrateSelection() async {
    try {
      await HapticFeedback.selectionClick();
      _logger.debug('Haptic feedback: selection');
    } catch (e) {
      _logger.error('Failed to provide selection haptic feedback', error: e);
    }
  }
}
