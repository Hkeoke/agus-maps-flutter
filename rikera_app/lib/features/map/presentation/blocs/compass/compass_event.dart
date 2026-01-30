import 'package:equatable/equatable.dart';

/// Base class for compass events.
abstract class CompassEvent extends Equatable {
  const CompassEvent();

  @override
  List<Object?> get props => [];
}

/// Event to start compass sensor.
class StartCompass extends CompassEvent {
  const StartCompass();
}

/// Event to stop compass sensor.
class StopCompass extends CompassEvent {
  const StopCompass();
}

/// Event when compass heading is updated.
class CompassHeadingUpdated extends CompassEvent {
  final double heading;

  const CompassHeadingUpdated(this.heading);

  @override
  List<Object?> get props => [heading];
}

/// Event to enable/disable compass-based map rotation.
class ToggleCompassRotation extends CompassEvent {
  final bool enabled;

  const ToggleCompassRotation(this.enabled);

  @override
  List<Object?> get props => [enabled];
}
