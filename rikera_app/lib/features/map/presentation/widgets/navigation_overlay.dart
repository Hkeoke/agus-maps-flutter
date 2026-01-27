import 'package:flutter/material.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/presentation/widgets/turn_instruction_widget.dart';
import 'package:rikera_app/features/map/presentation/widgets/speed_display_widget.dart';
import 'package:rikera_app/features/map/presentation/widgets/eta_display_widget.dart';
import 'package:rikera_app/features/map/presentation/widgets/navigation_controls_widget.dart';
import 'package:rikera_app/core/constants/app_constants.dart';
import 'package:rikera_app/core/theme/theme.dart';

/// Navigation UI overlay widget.
///
/// Displays turn instructions, speed, ETA, and controls on top of the map.
///
/// Requirements: 6.1, 6.2, 9.2
class NavigationOverlay extends StatelessWidget {
  final NavigationState navigationState;
  final VoidCallback onStopNavigation;
  final VoidCallback onToggleVoice;
  final VoidCallback onSettings;
  final bool isVoiceEnabled;

  const NavigationOverlay({
    super.key,
    required this.navigationState,
    required this.onStopNavigation,
    required this.onToggleVoice,
    required this.onSettings,
    required this.isVoiceEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Top section: Turn instructions, speed, ETA
          Container(
            color: Colors.black.withValues(alpha: 0.7),
            child: Column(
              children: [
                // Turn instruction display
                TurnInstructionWidget(navigationState: navigationState),

                const SizedBox(height: 16),

                // Speed display
                SpeedDisplayWidget(
                  navigationState: navigationState,
                  speedUnit: SpeedUnit.kmh, // TODO: Get from settings
                ),

                const SizedBox(height: 16),

                // ETA and distance display
                EtaDisplayWidget(navigationState: navigationState),

                const SizedBox(height: 16),
              ],
            ),
          ),

          const Spacer(),

          // Bottom section: Navigation controls
          Container(
            color: Colors.black.withValues(alpha: 0.7),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: NavigationControlsWidget(
              onStopNavigation: onStopNavigation,
              onToggleVoice: onToggleVoice,
              onSettings: onSettings,
              isVoiceEnabled: isVoiceEnabled,
            ),
          ),
        ],
      ),
    );
  }
}
