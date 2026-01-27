import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rikera_app/core/theme/theme.dart';
import 'package:rikera_app/features/settings/presentation/screens/settings_screen.dart';
import '../blocs/blocs.dart';
import '../screens/search_screen.dart';
import '../screens/bookmarks_screen.dart';
import '../screens/map_downloads_screen.dart';

/// Floating action buttons for map controls.
///
/// Provides quick access to:
/// - My location and zoom controls (left side)
/// - Search, bookmarks, downloads, settings (right side)
///
/// Requirements: 9.1, 2.5
class MapFloatingActions extends StatelessWidget {
  const MapFloatingActions({
    super.key,
  });

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
                  _MapActionButton(
                    icon: Icons.my_location,
                    label: 'My Location',
                    onPressed: () => mapController.switchMyPositionMode(),
                  ),
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

            // Right side controls (Menu & Tools)
            Align(
              alignment: Alignment.bottomRight,
              child: Column(
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
