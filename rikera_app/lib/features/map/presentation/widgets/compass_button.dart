import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rikera_app/features/map/presentation/blocs/blocs.dart';

/// Button to toggle compass-based map rotation.
///
/// Shows the current compass state and allows users to enable/disable
/// automatic map rotation based on device orientation.
/// 
/// Note: Compass rotation is automatically enabled in FOLLOW_AND_ROTATE mode (4)
/// because the map needs compass data to rotate during navigation.
class CompassButton extends StatelessWidget {
  const CompassButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CompassBloc, CompassState>(
      builder: (context, compassState) {
        return BlocBuilder<MapCubit, MapState>(
          builder: (context, mapState) {
            final isActive = compassState is CompassActive && compassState.rotationEnabled;
            final isFollowAndRotate = mapState is MapReady && mapState.myPositionMode == 4;
            
            // Show as active if compass is on OR if in FOLLOW_AND_ROTATE mode
            final showAsActive = isActive || isFollowAndRotate;
            
            return FloatingActionButton(
              heroTag: 'compass_button',
              mini: true,
              backgroundColor: showAsActive 
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surface,
              onPressed: () {
                if (compassState is CompassActive) {
                  context.read<CompassBloc>().add(
                    ToggleCompassRotation(!compassState.rotationEnabled),
                  );
                } else if (compassState is CompassInitial || compassState is CompassStopped) {
                  context.read<CompassBloc>().add(const StartCompass());
                }
              },
              child: Icon(
                Icons.explore,
                color: showAsActive
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            );
          },
        );
      },
    );
  }
}
