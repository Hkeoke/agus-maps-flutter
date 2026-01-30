import 'package:equatable/equatable.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';

/// Base class for all map events.
abstract class MapEvent extends Equatable {
  const MapEvent();

  @override
  List<Object?> get props => [];
}

/// Event triggered when the map surface is ready for interaction.
class MapReadyEvent extends MapEvent {
  const MapReadyEvent();
}

/// Event to check if map data needs to be downloaded for a location.
class CheckMapDownloadRequired extends MapEvent {
  final Location location;

  const CheckMapDownloadRequired(this.location);

  @override
  List<Object?> get props => [location];
}

/// Event to handle map selection (tap on map).
class HandleMapSelection extends MapEvent {
  final Map<String, dynamic> selectionInfo;

  const HandleMapSelection(this.selectionInfo);

  @override
  List<Object?> get props => [selectionInfo];
}

/// Event to dismiss the map download check dialog.
class DismissMapDownloadCheck extends MapEvent {
  const DismissMapDownloadCheck();
}

/// Event to re-register all downloaded maps.
class ReRegisterDownloadedMaps extends MapEvent {
  const ReRegisterDownloadedMaps();
}

/// Event triggered when My Position mode changes from native.
class MyPositionModeChanged extends MapEvent {
  final int mode;

  const MyPositionModeChanged(this.mode);

  @override
  List<Object?> get props => [mode];
}
