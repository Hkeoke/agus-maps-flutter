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
    return Stack(
      children: [
        // Top section: Turn instructions
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            margin: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFF1A73E8), // Google Maps Blue
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(80),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TurnInstructionWidget(navigationState: navigationState),
          ),
        ),

        // Bottom section: Speed, ETA, Controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Speed and Speed Limit floating on the left/bottom
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SpeedDisplayWidget(
                      navigationState: navigationState,
                      speedUnit: SpeedUnit.kmh,
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              
              // Bottom Bar with ETA and Controls
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E), // Dark Mode card color
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(100),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 32),
                child: Column(
                  children: [
                    EtaDisplayWidget(navigationState: navigationState),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(color: Colors.white24),
                    ),
                    NavigationControlsWidget(
                      onStopNavigation: onStopNavigation,
                      onToggleVoice: onToggleVoice,
                      onSettings: onSettings,
                      isVoiceEnabled: isVoiceEnabled,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
