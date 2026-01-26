import '../entities/location.dart';
import '../repositories/map_view_state_repository.dart';
import '../../../../core/utils/result.dart';

/// Use case for saving the current map view state.
///
/// This use case persists the map location and zoom level so they can
/// be restored when the app restarts.
///
/// Requirements: 12.3
class SaveMapViewStateUseCase {
  final MapViewStateRepository _repository;

  SaveMapViewStateUseCase(this._repository);

  Future<Result<void>> execute({
    required Location location,
    required int zoom,
  }) async {
    return await _repository.saveMapViewState(location: location, zoom: zoom);
  }
}
