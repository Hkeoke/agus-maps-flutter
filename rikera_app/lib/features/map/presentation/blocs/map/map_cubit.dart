import 'package:flutter/material.dart' hide Route;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rikera_app/core/services/map_style_manager.dart';
import 'package:rikera_app/core/utils/logger.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/domain/repositories/map_repository.dart';
import 'package:rikera_app/features/map/domain/usecases/save_map_view_state_usecase.dart';
import 'package:rikera_app/features/map/domain/usecases/load_map_view_state_usecase.dart';
import 'map_state.dart';

/// Cubit for managing map display state.
///
/// This cubit handles map view operations including:
/// - Moving to a specific location
/// - Changing zoom level
/// - Displaying route overlays
/// - Clearing route overlays
/// - Persisting and restoring map view state
/// - Registering bundled maps when map surface is ready
///
/// Requirements: 2.4, 5.2, 12.3
class MapCubit extends Cubit<MapState> {
  final SaveMapViewStateUseCase? _saveMapViewStateUseCase;
  final LoadMapViewStateUseCase? _loadMapViewStateUseCase;
  final MapRepository? _mapRepository;
  final AppLogger _logger = const AppLogger('MapCubit');
  bool _bundledMapsRegistered = false;

  MapCubit({
    SaveMapViewStateUseCase? saveMapViewStateUseCase,
    LoadMapViewStateUseCase? loadMapViewStateUseCase,
    MapRepository? mapRepository,
  }) : _saveMapViewStateUseCase = saveMapViewStateUseCase,
       _loadMapViewStateUseCase = loadMapViewStateUseCase,
       _mapRepository = mapRepository,
       super(MapState.initial());

  /// Moves the map to center on the specified [location].
  ///
  /// This updates the map view to display the given location at the center.
  /// The zoom level remains unchanged unless specified.
  ///
  /// Requirements: 2.4, 12.3
  void moveToLocation(Location location, {int? zoom}) {
    emit(state.copyWith(location: location, zoom: zoom));
    _saveMapViewState();
  }

  /// Sets the map zoom level.
  ///
  /// Higher values zoom in closer, lower values zoom out.
  /// Typical range is 1-20, with 12 being a good default for city-level view.
  ///
  /// Requirements: 2.4, 12.3
  void setZoom(int zoom) {
    emit(state.copyWith(zoom: zoom));
    _saveMapViewState();
  }

  /// Displays a route overlay on the map.
  ///
  /// This renders the route path on the map, typically as a polyline
  /// connecting the waypoints. The route remains visible until cleared.
  ///
  /// Requirements: 5.2
  void showRoute(Route route) {
    emit(state.copyWith(routeOverlay: route));
  }

  /// Clears the current route overlay from the map.
  ///
  /// This removes any displayed route, returning the map to a clean state.
  ///
  /// Requirements: 5.2
  void clearRoute() {
    emit(state.copyWith(clearRoute: true));
  }

  /// Updates both location and route simultaneously.
  ///
  /// This is useful when starting navigation to both center the map
  /// on the route and display the route overlay.
  void updateLocationAndRoute(Location location, Route route, {int? zoom}) {
    emit(state.copyWith(location: location, routeOverlay: route, zoom: zoom));
  }

  /// Syncs map style with the current theme brightness.
  ///
  /// This should be called when the app theme changes to ensure
  /// the map style matches (light/dark mode).
  ///
  /// Requirements: 8.2
  void syncMapStyle(Brightness brightness) {
    MapStyleManager.syncWithTheme(brightness);
  }

  /// Restores the last saved map view state.
  ///
  /// This should be called when the app starts to restore the map
  /// to the last viewed location and zoom level.
  ///
  /// Requirements: 12.3
  Future<void> restoreMapViewState() async {
    if (_loadMapViewStateUseCase == null) return;

    try {
      final result = await _loadMapViewStateUseCase.execute();
      if (result.isSuccess && result.valueOrNull != null) {
        final savedState = result.valueOrNull!;
        emit(
          state.copyWith(location: savedState.location, zoom: savedState.zoom),
        );
      }
    } catch (e) {
      // If restoration fails, continue with default state
      // Error is silently ignored as this is not critical
    }
  }

  /// Saves the current map view state for restoration on next app start.
  ///
  /// This is called automatically when the map location or zoom changes.
  ///
  /// Requirements: 12.3
  Future<void> _saveMapViewState() async {
    if (_saveMapViewStateUseCase == null || state.location == null) return;

    try {
      await _saveMapViewStateUseCase.execute(
        location: state.location!,
        zoom: state.zoom,
      );
    } catch (e) {
      // If saving fails, continue without persistence
      // Error is silently ignored as this is not critical
    }
  }

  /// Registers bundled maps with the CoMaps engine.
  ///
  /// This should be called once when the map surface is ready.
  /// Bundled maps (World.mwm, WorldCoasts.mwm) are extracted during
  /// app initialization and registered here after the map is created.
  ///
  /// Requirements: 2.1, 2.6
  Future<void> registerBundledMaps() async {
    if (_bundledMapsRegistered || _mapRepository == null) return;

    try {
      _logger.info('Registering bundled maps with CoMaps engine...');

      // Get all downloaded maps (includes bundled maps)
      final result = await _mapRepository.getDownloadedRegions();

      if (result.isSuccess) {
        final regions = result.valueOrNull ?? [];
        final bundledRegions = regions.where((r) => r.isBundled).toList();

        for (final region in bundledRegions) {
          try {
            _logger.info('Registering ${region.name}...');
            final registerResult = await _mapRepository.registerMapFile(
              region.filePath,
            );

            if (registerResult.isSuccess) {
              _logger.info('Successfully registered ${region.name}');
            } else {
              _logger.error(
                'Failed to register ${region.name}: ${registerResult.errorOrNull}',
              );
            }
          } catch (e) {
            _logger.error('Error registering ${region.name}', error: e);
          }
        }

        _bundledMapsRegistered = true;
        _logger.info('Bundled maps registration completed');
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to register bundled maps',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
