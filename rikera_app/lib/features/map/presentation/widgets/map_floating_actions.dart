import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rikera_app/core/theme/theme.dart';
import 'package:rikera_app/features/settings/presentation/screens/settings_screen.dart';
import '../blocs/blocs.dart';
import '../screens/search_screen.dart';
import '../screens/bookmarks_screen.dart';
import '../screens/map_downloads_screen.dart';
import 'my_location_button.dart';
import 'compass_button.dart';

/// Floating action buttons for map controls.
///
/// Provides quick access to:
/// - My location and zoom controls (left side)
/// - Search, bookmarks, downloads, settings (right side)
/// - Navigation info (replaces right side during navigation)
///
/// Requirements: 9.1, 2.5
class MapFloatingActions extends StatelessWidget {
  const MapFloatingActions({
    super.key,
  });

  String _formatETA(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  String _formatSpeed(double speedMps) {
    if (speedMps < 0) {
      return '-- km/h';
    }
    final speedKmh = speedMps * 3.6;
    return '${speedKmh.toStringAsFixed(0)} km/h';
  }

  @override
  Widget build(BuildContext context) {
    final mapController = context.read<MapCubit>().mapController;
    
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Stack(
          children: [
            // Left side controls (Navigation & Zoom)
            Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MyLocationButton(),
                  const SizedBox(height: AppSpacing.md),
                  const CompassButton(),
                  const SizedBox(height: AppSpacing.md),
                  _MapActionButton(
                    icon: Icons.add,
                    label: 'Zoom In',
                    onPressed: () => mapController.zoomIn(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _MapActionButton(
                    icon: Icons.remove,
                    label: 'Zoom Out',
                    onPressed: () => mapController.zoomOut(),
                  ),
                ],
              ),
            ),

            // Right side controls (Menu & Tools) - ALWAYS VISIBLE
            // During navigation: show nav info
            // Normal: show buttons
            Align(
              alignment: Alignment.bottomRight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Navigation info OR normal buttons - ALWAYS one of them
                  BlocBuilder<NavigationInfoCubit, NavigationInfoState>(
                    builder: (context, navInfoState) {
                      final isNavigating = navInfoState is NavigationInfoActive;
                      print('[MapFloatingActions] isNavigating: $isNavigating, state: $navInfoState');
                      
                      if (isNavigating) {
                        // Navigation info card - mismo estilo que FloatingActionButton
                        print('[MapFloatingActions] Building navigation info card');
                        return Container(
                          width: 56,
                          decoration: BoxDecoration(
                            color: Theme.of(context).floatingActionButtonTheme.backgroundColor ?? 
                                   Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 12),
                              // ETA
                              Icon(
                                Icons.access_time,
                                size: 20,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatETA(navInfoState.timeToTarget),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              // Distance
                              Icon(
                                Icons.straighten,
                                size: 18,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatDistance(navInfoState.distanceToTarget),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 8,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              // Speed
                              Icon(
                                Icons.speed,
                                size: 18,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatSpeed(navInfoState.speedMps),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 8,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              // Stop button
                              InkWell(
                                onTap: () {
                                  print('[MapFloatingActions] Stop button pressed');
                                  context.read<NavigationInfoCubit>().stopNavigation();
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.error,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.onError,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        );
                      }
                      
                      // Normal buttons when NOT navigating
                      print('[MapFloatingActions] Building normal buttons');
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _MapActionButton(
                            icon: Icons.search,
                            label: 'Search',
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const SearchScreen(),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _MapActionButton(
                            icon: Icons.bookmarks,
                            label: 'Bookmarks',
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const BookmarksScreen(),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _MapActionButton(
                            icon: Icons.download,
                            label: 'Maps',
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const MapDownloadsScreen(),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _MapActionButton(
                            icon: Icons.settings,
                            label: 'Settings',
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const SettingsScreen(),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Single action button with consistent styling.
///
/// Ensures minimum 48dp touch target and high contrast colors.
class _MapActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _MapActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: FloatingActionButton(
        heroTag: label,
        onPressed: onPressed,
        tooltip: label,
        child: Icon(icon, size: 28),
      ),
    );
  }
}
