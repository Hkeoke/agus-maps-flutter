import 'package:flutter/material.dart';

/// Widget displaying navigation controls.
///
/// Shows:
/// - Stop navigation button (large, accessible)
/// - Voice guidance toggle
/// - Settings button
///
/// Requirements: 6.7, 14.4, 9.1
class NavigationControlsWidget extends StatelessWidget {
  final VoidCallback onStopNavigation;
  final VoidCallback onToggleVoice;
  final VoidCallback onSettings;
  final bool isVoiceEnabled;

  const NavigationControlsWidget({
    super.key,
    required this.onStopNavigation,
    required this.onToggleVoice,
    required this.onSettings,
    this.isVoiceEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Voice guidance toggle
        _buildControlButton(
          icon: isVoiceEnabled ? Icons.volume_up : Icons.volume_off,
          label: 'Voice',
          onPressed: onToggleVoice,
          color: isVoiceEnabled ? Colors.blue : Colors.grey,
        ),

        // Stop navigation button (larger, more prominent)
        _buildStopButton(context),

        // Settings button
        _buildControlButton(
          icon: Icons.settings,
          label: 'Settings',
          onPressed: onSettings,
          color: Colors.grey,
        ),
      ],
    );
  }

  /// Builds a standard control button.
  ///
  /// Ensures minimum 48dp touch target for driving safety.
  ///
  /// Requirements: 9.1
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return SizedBox(
      width: 80,
      height: 60,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 12, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the stop navigation button.
  ///
  /// Larger and more prominent than other controls for safety.
  ///
  /// Requirements: 6.7, 9.1
  Widget _buildStopButton(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 60,
      child: ElevatedButton(
        onPressed: onStopNavigation,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.stop, size: 24),
            SizedBox(width: 8),
            Text(
              'Stop',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
