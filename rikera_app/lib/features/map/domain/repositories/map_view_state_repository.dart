import '../entities/location.dart';
import '../usecases/load_map_view_state_usecase.dart';
import '../../../../core/utils/result.dart';

/// Repository interface for map view state persistence.
///
/// This repository handles saving and loading the map view state
/// (location and zoom level) for restoration on app restart.
///
/// Requirements: 12.3
abstract class MapViewStateRepository {
  /// Saves the current map view state.
  Future<Result<void>> saveMapViewState({
    required Location location,
    required int zoom,
  });

  /// Loads the saved map view state.
  ///
  /// Returns null if no state has been saved.
  Future<Result<MapViewStateData?>> loadMapViewState();

  /// Clears the saved map view state.
  Future<Result<void>> clearMapViewState();
}
