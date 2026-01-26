import '../../domain/entities/location.dart';
import '../../domain/repositories/map_view_state_repository.dart';
import '../../domain/usecases/load_map_view_state_usecase.dart';
import '../datasources/map_view_state_datasource.dart';
import '../../../../core/utils/result.dart';

/// Error for map view state operations.
class MapViewStateError extends AppError {
  const MapViewStateError(String message)
    : super(message: message, code: 'MAP_VIEW_STATE_ERROR');
}

/// Implementation of MapViewStateRepository.
///
/// This repository uses MapViewStateDataSource to persist map view state
/// using SharedPreferences.
///
/// Requirements: 12.3
class MapViewStateRepositoryImpl implements MapViewStateRepository {
  final MapViewStateDataSource _dataSource;

  MapViewStateRepositoryImpl(this._dataSource);

  @override
  Future<Result<void>> saveMapViewState({
    required Location location,
    required int zoom,
  }) async {
    try {
      await _dataSource.saveMapViewState(
        MapViewState(location: location, zoom: zoom),
      );
      return Result.success(null);
    } catch (e) {
      return Result.failure(
        MapViewStateError('Failed to save map view state: $e'),
      );
    }
  }

  @override
  Future<Result<MapViewStateData?>> loadMapViewState() async {
    try {
      final state = await _dataSource.loadMapViewState();
      if (state == null) {
        return Result.success(null);
      }
      return Result.success(
        MapViewStateData(location: state.location, zoom: state.zoom),
      );
    } catch (e) {
      return Result.failure(
        MapViewStateError('Failed to load map view state: $e'),
      );
    }
  }

  @override
  Future<Result<void>> clearMapViewState() async {
    try {
      await _dataSource.clearMapViewState();
      return Result.success(null);
    } catch (e) {
      return Result.failure(
        MapViewStateError('Failed to clear map view state: $e'),
      );
    }
  }
}
