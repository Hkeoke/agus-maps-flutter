import 'package:equatable/equatable.dart';

/// Base class for compass states.
abstract class CompassState extends Equatable {
  const CompassState();

  @override
  List<Object?> get props => [];
}

/// Initial state before compass is started.
class CompassInitial extends CompassState {
  const CompassInitial();
}

/// Compass is active and providing heading data.
class CompassActive extends CompassState {
  final double heading;
  final bool rotationEnabled;

  const CompassActive({
    required this.heading,
    required this.rotationEnabled,
  });

  @override
  List<Object?> get props => [heading, rotationEnabled];

  CompassActive copyWith({
    double? heading,
    bool? rotationEnabled,
  }) {
    return CompassActive(
      heading: heading ?? this.heading,
      rotationEnabled: rotationEnabled ?? this.rotationEnabled,
    );
  }
}

/// Compass is stopped.
class CompassStopped extends CompassState {
  const CompassStopped();
}

/// Compass is not available on this device.
class CompassUnavailable extends CompassState {
  const CompassUnavailable();
}
