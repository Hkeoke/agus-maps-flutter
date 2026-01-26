import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agus_maps_flutter/agus_maps_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:rikera_app/features/map/presentation/blocs/blocs.dart';
import 'package:rikera_app/features/map/presentation/widgets/turn_instruction_widget.dart';
import 'package:rikera_app/features/map/presentation/widgets/speed_display_widget.dart';
import 'package:rikera_app/features/map/presentation/widgets/eta_display_widget.dart';
import 'package:rikera_app/features/map/presentation/widgets/navigation_controls_widget.dart';
import 'package:rikera_app/core/constants/app_constants.dart';

/// Full-screen navigation view with turn-by-turn instructions.
///
/// This screen provides a driving-optimized interface with:
/// - Full-screen map view
/// - Large turn instruction display
/// - Speed and speed limit indicators
/// - ETA and distance information
/// - Navigation controls
///
/// Requirements: 6.1, 6.2, 6.6, 5.3, 6.7, 9.1, 9.2, 9.4, 14.4, 15.1-15.5
class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  late final AgusMapController _mapController;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _mapController = AgusMapController();
    _enableWakeLock();
  }

  @override
  void dispose() {
    _disableWakeLock();
    super.dispose();
  }

  void _onMapReady() {
    setState(() {
      _isMapReady = true;
    });
    debugPrint('[NavigationScreen] Map is ready');
  }

  /// Enables wake lock to keep screen on during navigation.
  ///
  /// Requirements: 9.4
  Future<void> _enableWakeLock() async {
    try {
      await WakelockPlus.enable();
      debugPrint('[NavigationScreen] Wake lock enabled');
    } catch (e) {
      debugPrint('[NavigationScreen] Failed to enable wake lock: $e');
    }
  }

  /// Disables wake lock when navigation stops.
  ///
  /// Requirements: 9.4
  Future<void> _disableWakeLock() async {
    try {
      await WakelockPlus.disable();
      debugPrint('[NavigationScreen] Wake lock disabled');
    } catch (e) {
      debugPrint('[NavigationScreen] Failed to disable wake lock: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<NavigationBloc, NavigationBlocState>(
        listener: (context, state) {
          // Handle navigation state changes
          if (state is NavigationArrived) {
            _handleArrival(context);
          } else if (state is NavigationError) {
            _showError(context, state.message);
          }
        },
        child: Stack(
          children: [
            // Full-screen map view
            _buildMap(),

            // Navigation UI overlay
            _buildNavigationOverlay(),
          ],
        ),
      ),
    );
  }

  /// Builds the full-screen map widget.
  ///
  /// Requirements: 6.1
  Widget _buildMap() {
    return BlocConsumer<MapCubit, MapState>(
      listener: (context, mapState) {
        if (_isMapReady && mapState.location != null) {
          _mapController.moveToLocation(
            mapState.location!.latitude,
            mapState.location!.longitude,
            mapState.zoom,
          );
        }
      },
      builder: (context, mapState) {
        return AgusMap(
          controller: _mapController,
          initialLat: mapState.location?.latitude ?? 14.5995,
          initialLon: mapState.location?.longitude ?? 120.9842,
          initialZoom: 17, // Closer zoom for navigation
          onMapReady: _onMapReady,
        );
      },
    );
  }

  /// Builds the navigation UI overlay on top of the map.
  ///
  /// This includes turn instructions, speed display, ETA, and controls.
  ///
  /// Requirements: 6.1, 6.2, 9.2
  Widget _buildNavigationOverlay() {
    return BlocBuilder<NavigationBloc, NavigationBlocState>(
      builder: (context, navState) {
        if (navState is! NavigationNavigating &&
            navState is! NavigationOffRoute) {
          return const SizedBox.shrink();
        }

        final navigationState = navState is NavigationNavigating
            ? navState.navigationState
            : (navState as NavigationOffRoute).navigationState;

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
                padding: const EdgeInsets.all(16),
                child: NavigationControlsWidget(
                  onStopNavigation: () => _stopNavigation(context),
                  onToggleVoice: () => _toggleVoice(context),
                  onSettings: () => _openSettings(context),
                  isVoiceEnabled: true, // TODO: Get from settings
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Handles arrival at destination.
  ///
  /// Requirements: 6.7
  void _handleArrival(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Arrived'),
        content: const Text('You have reached your destination.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Return to map screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Shows an error message.
  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// Stops navigation and returns to map screen.
  ///
  /// Requirements: 6.7, 9.4
  void _stopNavigation(BuildContext context) {
    context.read<NavigationBloc>().add(const StopNavigation());
    _disableWakeLock();
    Navigator.of(context).pop();
  }

  /// Toggles voice guidance on/off.
  ///
  /// Requirements: 14.4
  void _toggleVoice(BuildContext context) {
    // TODO: Implement voice guidance toggle when VoiceGuidanceService is available
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Voice guidance toggle coming soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Opens settings screen.
  void _openSettings(BuildContext context) {
    // TODO: Navigate to settings screen (will be implemented in task 14)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings screen coming soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
