import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';

/// My Location button that changes icon based on position mode.
///
/// Position modes:
/// - 0: PENDING_POSITION (waiting for first location)
/// - 1: NOT_FOLLOW_NO_POSITION (no location, not following)
/// - 2: NOT_FOLLOW (has location but not following)
/// - 3: FOLLOW (following user location)
/// - 4: FOLLOW_AND_ROTATE (following and rotating map)
class MyLocationButton extends StatelessWidget {
  const MyLocationButton({super.key});

  IconData _getIconForMode(int mode) {
    switch (mode) {
      case 0: // PENDING_POSITION - searching/loading
        return Icons.location_searching;
      case 1: // NOT_FOLLOW_NO_POSITION - location disabled
        return Icons.location_disabled;
      case 2: // NOT_FOLLOW - crosshair (location available but not following)
        return Icons.gps_not_fixed; // Crosshair icon
      case 3: // FOLLOW - following location (arrow pointing up)
        return Icons.navigation_outlined; // Arrow icon
      case 4: // FOLLOW_AND_ROTATE - following with rotation (filled arrow)
        return Icons.navigation; // Filled navigation arrow
      default:
        return Icons.location_searching;
    }
  }

  Color? _getColorForMode(int mode, BuildContext context) {
    final theme = Theme.of(context);
    switch (mode) {
      case 0: // PENDING_POSITION - use primary color (searching)
        return theme.colorScheme.primary;
      case 1: // NOT_FOLLOW_NO_POSITION - use error color (disabled)
        return theme.colorScheme.error;
      case 2: // NOT_FOLLOW - use normal icon tint
        return theme.colorScheme.onSurface;
      case 3: // FOLLOW - use primary color (active)
        return theme.colorScheme.primary;
      case 4: // FOLLOW_AND_ROTATE - use primary color (active)
        return theme.colorScheme.primary;
      default:
        return null;
    }
  }

  String _getTooltipForMode(int mode) {
    switch (mode) {
      case 0:
        return 'Searching for location...';
      case 1:
        return 'Location disabled';
      case 2:
        return 'Show my location';
      case 3:
        return 'Following location';
      case 4:
        return 'Following with rotation';
      default:
        return 'My Location';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MapCubit, MapState>(
      buildWhen: (previous, current) {
        // Only rebuild when myPositionMode changes
        if (previous is MapReady && current is MapReady) {
          return previous.myPositionMode != current.myPositionMode;
        }
        return true;
      },
      builder: (context, state) {
        final mode = state is MapReady ? state.myPositionMode : 0;
        
        return SizedBox(
          width: 56,
          height: 56,
          child: FloatingActionButton(
            heroTag: 'my_location',
            onPressed: () => context.read<MapCubit>().switchMyPositionMode(),
            tooltip: _getTooltipForMode(mode),
            child: Icon(
              _getIconForMode(mode),
              size: 28,
              color: _getColorForMode(mode, context),
            ),
          ),
        );
      },
    );
  }
}
