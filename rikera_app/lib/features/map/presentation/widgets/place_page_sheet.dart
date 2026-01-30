import 'package:flutter/material.dart' hide Route;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agus_maps_flutter/agus_maps_flutter.dart';
import 'package:rikera_app/core/theme/theme.dart';
import 'package:rikera_app/features/map/presentation/blocs/blocs.dart';
import 'package:rikera_app/features/map/presentation/blocs/navigation_info/navigation_info_cubit.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';

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
                    
                    print('[PlacePageSheet] Building route to: $dLat, $dLon');
                    
                    // Simply call buildRoute on the motor
                    // The motor will:
                    // 1. Calculate the route
                    // 2. Activate navigation mode (mode 4)
                    // 3. Start following the route
                    // 4. Calculate real-time navigation info
                    await mapController.buildRoute(dLat, dLon);
                    
                    print('[PlacePageSheet] Route built, starting navigation info polling');
                    
                    // Start navigation info polling
                    // This will keep showing navigation info even when user moves the map
                    // (which changes mode from 4 to 3)
                    if (context.mounted) {
                      context.read<NavigationInfoCubit>().startNavigation();
                    }
                    
                    print('[PlacePageSheet] Navigation started!');
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
