import 'package:flutter/material.dart' hide Route;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agus_maps_flutter/agus_maps_flutter.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/presentation/blocs/blocs.dart';
import 'package:rikera_app/features/map/presentation/widgets/widgets.dart';

/// Full-screen navigation view with turn-by-turn instructions.
///
/// Requirements: 6.1, 6.2, 6.6, 5.3, 6.7, 9.1, 9.2, 9.4, 14.4, 15.1-15.5
class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  bool _navigationStarted = false;

  @override
  void initState() {
    super.initState();
    // Start navigation after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startNavigation();
    });
  }

  void _startNavigation() {
    if (_navigationStarted) return;
    _navigationStarted = true;

    final mapCubit = context.read<MapCubit>();
    final navigationBloc = context.read<NavigationBloc>();
    
    // Create a minimal route entity for navigation
    // The native engine already has the route, we just need a placeholder
    final route = Route(
      waypoints: [], // Native engine has the actual waypoints
      totalDistanceMeters: 0, // Will be updated from native
      estimatedTimeSeconds: 0, // Will be updated from native
      segments: [], // Native engine has the actual segments
      bounds: const RouteBounds(
        minLatitude: 0,
        minLongitude: 0,
        maxLatitude: 0,
        maxLongitude: 0,
      ),
    );

    // Start navigation with map controller
    navigationBloc.add(StartNavigation(route, mapController: mapCubit.mapController));
  }

  @override
  Widget build(BuildContext context) {
    final mapCubit = context.read<MapCubit>();
    
    return Scaffold(
      body: MultiBlocListener(
        listeners: [
          // Listen to location updates and send them to the native map
          BlocListener<LocationBloc, LocationState>(
            listener: (context, locationState) {
              if (locationState is LocationTracking) {
                // Update location in MapCubit
                mapCubit.updateLocation(locationState.location);
                
                // Send location to native map for "My Position" icon and navigation
                final loc = locationState.location;
                final bearing = loc.heading ?? -1.0;
                final speed = loc.speed ?? -1.0;
                
                mapCubit.mapController.setMyPosition(
                  loc.latitude,
                  loc.longitude,
                  loc.accuracy ?? 0.0,
                  bearing,
                  speed,
                  loc.timestamp.millisecondsSinceEpoch,
                );

                if (bearing >= 0) {
                  mapCubit.mapController.setCompass(bearing);
                }
              }
            },
          ),
          // Listen to navigation state changes
          BlocListener<NavigationBloc, NavigationBlocState>(
            listener: (context, state) {
              if (state is NavigationArrived) {
                _showArrivalDialog(context);
              } else if (state is NavigationError) {
                _showErrorSnackBar(context, state.message);
              }
            },
          ),
        ],
        child: Stack(
          children: [
            BlocBuilder<MapCubit, MapState>(
              builder: (context, mapState) {
                final location = mapState is MapReady ? mapState.location : null;
                final zoom = mapState is MapReady ? mapState.zoom : 17;
                
                return AgusMap(
                  controller: mapCubit.mapController,
                  initialLat: location?.latitude ?? 14.5995,
                  initialLon: location?.longitude ?? 120.9842,
                  initialZoom: zoom,
                  onMapReady: () => debugPrint('[NavigationScreen] Map is ready'),
                );
              },
            ),
            BlocBuilder<NavigationBloc, NavigationBlocState>(
              builder: (context, navState) {
                if (navState is! NavigationNavigating && navState is! NavigationOffRoute) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final navigationState = navState is NavigationNavigating
                    ? navState.navigationState
                    : (navState as NavigationOffRoute).navigationState;

                return NavigationOverlay(
                  navigationState: navigationState,
                  onStopNavigation: () {
                    context.read<NavigationBloc>().add(const StopNavigation());
                    context.read<RouteBloc>().add(const ClearRoute());
                    Navigator.of(context).pop();
                  },
                  onToggleVoice: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Voice guidance toggle coming soon'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  onSettings: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Settings screen coming soon'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  isVoiceEnabled: true,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showArrivalDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ArrivalDialog(),
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}
