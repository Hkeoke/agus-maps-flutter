import 'package:flutter/material.dart' hide Route;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agus_maps_flutter/agus_maps_flutter.dart';
import 'package:rikera_app/core/theme/theme.dart';
import 'package:rikera_app/features/map/presentation/blocs/blocs.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/presentation/screens/navigation_screen.dart';

/// Bottom sheet displaying place information when map is tapped.
///
/// Shows place title, subtitle, and action buttons.
///
/// Requirements: 2.1
class PlacePageSheet extends StatelessWidget {
  final Map<String, dynamic> info;
  final AgusMapController mapController;

  const PlacePageSheet({
    super.key,
    required this.info,
    required this.mapController,
  });

  @override
  Widget build(BuildContext context) {
    final title = info['title'] ?? 'Unknown Place';
    final subtitle = info['subtitle'] ?? '';
    final lat = info['lat'];
    final lon = info['lon'];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (subtitle.isNotEmpty)
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.directions),
                label: const Text('IR AQUI (RUTA)'),
                onPressed: () async {
                  Navigator.pop(context);
                  if (lat != null && lon != null) {
                    final dLat = lat is String
                        ? double.parse(lat)
                        : (lat as num).toDouble();
                    final dLon = lon is String
                        ? double.parse(lon)
                        : (lon as num).toDouble();
                    
                    // Build route via MapCubit and get controller
                    final mapCubit = context.read<MapCubit>();
                    await mapCubit.buildRouteAndPrepareNavigation(dLat, dLon);
                    
                    // Navigate to navigation screen
                    // The native engine is now following the route
                      // Create route object with destination
                      // This ensures NavigationRepository has destination for recalculation
                      final route = Route(
                        waypoints: [
                          Location(
                            latitude: dLat,
                            longitude: dLon,
                            timestamp: DateTime.now(),
                          ),
                        ],
                        totalDistanceMeters: 0,
                        estimatedTimeSeconds: 0,
                        segments: [],
                        bounds: const RouteBounds(
                          minLatitude: 0,
                          minLongitude: 0,
                          maxLatitude: 0,
                          maxLongitude: 0,
                        ),
                      );

                      if (context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => NavigationScreen(route: route),
                          ),
                        );
                      }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
