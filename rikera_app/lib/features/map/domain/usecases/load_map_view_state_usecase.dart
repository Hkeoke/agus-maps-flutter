import '../entities/location.dart';
import '../repositories/map_view_state_repository.dart';
import '../../../../core/utils/result.dart';

/// Represents the loaded map view state.
class MapViewStateData {
  final Location location;
  final int zoom;

  const MapViewStateData({required this.location, required this.zoom});
}

/// Use case for loading the saved map view state.
///
/// This use case retrieves the last saved map location and zoom level
/// so the map can be restored to its previous state.
///
/// Requirements: 12.3
class LoadMapViewStateUseCase {
  final MapViewStateRepository _repository;

  LoadMapViewStateUseCase(this._repository);

  Future<Result<MapViewStateData?>> execute() async {
    return await _repository.loadMapViewState();
  }
}
