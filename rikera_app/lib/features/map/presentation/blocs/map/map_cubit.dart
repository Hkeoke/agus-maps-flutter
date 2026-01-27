import 'dart:io';
import 'package:flutter/material.dart' hide Route;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agus_maps_flutter/agus_maps_flutter.dart';
import 'package:rikera_app/core/services/map_style_manager.dart';
import 'package:rikera_app/core/utils/logger.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/domain/repositories/map_repository.dart';
import 'package:rikera_app/features/map/domain/usecases/save_map_view_state_usecase.dart';
import 'package:rikera_app/features/map/domain/usecases/load_map_view_state_usecase.dart';
import 'map_event.dart';
import 'map_state.dart';

/// Bloc for managing map display state and interactions.
///
/// This bloc handles map view operations including:
/// - Map controller lifecycle
/// - Map ready initialization
/// - Moving to a specific location
/// - Changing zoom level
/// - Displaying route overlays
/// - Clearing route overlays
/// - Checking map download requirements
/// - Handling map selections
/// - Persisting and restoring map view state
/// - Registering bundled and downloaded maps
///
/// Requirements: 2.4, 5.2, 12.3
class MapCubit extends Bloc<MapEvent, MapState> {
  final SaveMapViewStateUseCase? _saveMapViewStateUseCase;
  final LoadMapViewStateUseCase? _loadMapViewStateUseCase;
  final MapRepository? _mapRepository;
  final AppLogger _logger = const AppLogger('MapCubit');
  bool _bundledMapsRegistered = false;
  bool _hasCheckedMapDownload = false;
  
  // Map controller managed by the BLoC
  late final AgusMapController mapController;

  MapCubit({
    SaveMapViewStateUseCase? saveMapViewStateUseCase,
    LoadMapViewStateUseCase? loadMapViewStateUseCase,
    MapRepository? mapRepository,
  })  : _saveMapViewStateUseCase = saveMapViewStateUseCase,
        _loadMapViewStateUseCase = loadMapViewStateUseCase,
        _mapRepository = mapRepository,
        super(const MapInitial()) {
    mapController = AgusMapController();
    on<MapReadyEvent>(_onMapReady);
    on<CheckMapDownloadRequired>(_onCheckMapDownloadRequired);
    on<HandleMapSelection>(_onHandleMapSelection);
    on<DismissMapDownloadCheck>(_onDismissMapDownloadCheck);
    on<ReRegisterDownloadedMaps>(_onReRegisterDownloadedMaps);
  }
  
  /// Updates the user's location on the map.
  void updateLocation(Location location) {
    if (state is MapReady) {
      final currentState = state as MapReady;
      emit(currentState.copyWith(location: location));
    }
  }

  /// Handles map ready event.
  Future<void> _onMapReady(MapReadyEvent event, Emitter<MapState> emit) async {
    emit(const MapReady());
    await registerBundledMaps();
    add(const ReRegisterDownloadedMaps());
    
    // Listen to native map selections (taps)
    mapController.onSelectionChanged.listen((selected) {
      if (selected) {
        _handleMapSelectionAsync();
      }
    });
    
    // Activate My Position mode automatically
    Future.delayed(const Duration(milliseconds: 500), () {
      mapController.switchMyPositionMode();
    });
    
    // After maps are registered, check if we need to download more
    // Wait a bit to ensure registration is complete
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (state is MapReady) {
        final location = (state as MapReady).location;
        if (location != null && !_hasCheckedMapDownload) {
          add(CheckMapDownloadRequired(location));
        }
      }
    });
  }
  
  /// Handles map selection asynchronously.
  Future<void> _handleMapSelectionAsync() async {
    final info = await mapController.getSelectionInfo();
    if (info != null) {
      add(HandleMapSelection(info));
    }
  }

  /// Handles checking if map download is required for a location.
  Future<void> _onCheckMapDownloadRequired(
    CheckMapDownloadRequired event,
    Emitter<MapState> emit,
  ) async {
    // Only check once per session, but allow re-check after download
    if (_hasCheckedMapDownload) return;

    try {
      final status = await checkMapStatus(
        event.location.latitude,
        event.location.longitude,
      );
      _logger.info(
        'CheckMapStatus: lat=${event.location.latitude} '
        'lon=${event.location.longitude} -> Status $status',
      );

      if (status == 2) {
        // NotDownloaded
        _hasCheckedMapDownload = true;
        final countryName = await getCountryName(
          event.location.latitude,
          event.location.longitude,
        );
        
        // Preserve current location in the state
        final currentLocation = (state is MapReady) 
            ? (state as MapReady).location ?? event.location
            : event.location;
            
        emit(MapDownloadRequired(
          countryName: countryName ?? 'this area',
          location: currentLocation,
        ));
      } else if (status == 1) {
        // OnDisk - map is available
        _hasCheckedMapDownload = true;
        _logger.info('Map is available for this location');
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to check map download status',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Handles map selection event.
  Future<void> _onHandleMapSelection(
    HandleMapSelection event,
    Emitter<MapState> emit,
  ) async {
    _logger.info('Selection info: ${event.selectionInfo}');
    _logger.info('Title: ${event.selectionInfo['title']}');
    _logger.info('Subtitle: ${event.selectionInfo['subtitle']}');
    _logger.info('Type: ${event.selectionInfo['type']}');
    _logger.info(
      'Lat: ${event.selectionInfo['lat']}, Lon: ${event.selectionInfo['lon']}',
    );

    emit(MapSelectionAvailable(event.selectionInfo));
  }

  /// Handles dismissing the map download check.
  void _onDismissMapDownloadCheck(
    DismissMapDownloadCheck event,
    Emitter<MapState> emit,
  ) {
    // Reset the flag so it can check again after download
    _hasCheckedMapDownload = false;
    
    // Restore MapReady state with current location
    final currentLocation = (state is MapDownloadRequired) 
        ? (state as MapDownloadRequired).location 
        : null;
    
    emit(MapReady(location: currentLocation));
  }

  /// Handles re-registering all downloaded maps.
  Future<void> _onReRegisterDownloadedMaps(
    ReRegisterDownloadedMaps event,
    Emitter<MapState> emit,
  ) async {
    if (_mapRepository == null) return;

    try {
      // Preserve current location before re-registering
      final currentLocation = (state is MapReady) ? (state as MapReady).location : null;
      final currentZoom = (state is MapReady) ? (state as MapReady).zoom : 15;
      
      _logger.info('Re-registering downloaded maps...');

      final downloadedResult = await _mapRepository.getDownloadedRegions();

      if (downloadedResult.isSuccess) {
        final maps = downloadedResult.valueOrNull ?? [];
        _logger.info('Found ${maps.length} downloaded maps for re-registration');

        int registeredCount = 0;
        for (final map in maps) {
          if (!map.isBundled) {
            try {
              _logger.info('Re-registering: ${map.name} at ${map.filePath}');
              
              // Verify file exists before attempting registration
              final file = File(map.filePath);
              if (!await file.exists()) {
                _logger.error('Map file not found: ${map.filePath}');
                continue;
              }
              
              final registerResult = await _mapRepository.registerMapFile(map.filePath);
              
              if (registerResult.isSuccess) {
                _logger.info('Successfully re-registered: ${map.name}');
                registeredCount++;
              } else {
                _logger.error('Failed to re-register ${map.name}: ${registerResult.errorOrNull}');
              }
            } catch (e) {
              _logger.error('Failed to re-register ${map.name}: $e');
            }
          }
        }

        _logger.info('Map re-registration completed: $registeredCount maps registered');
        
        // Force map redraw to load new tiles
        if (registeredCount > 0) {
          invalidateMap();
          forceRedraw();
        }
      }

      // Restore location after re-registration
      emit(MapReady(location: currentLocation, zoom: currentZoom));
    } catch (e, stackTrace) {
      _logger.error(
        'Error re-registering maps',
        error: e,
        stackTrace: stackTrace,
      );
      emit(const MapReady());
    }
  }

  /// Moves the map to center on the specified [location].
  ///
  /// This updates the map view to display the given location at the center.
  /// The zoom level remains unchanged unless specified.
  ///
  /// Requirements: 2.4, 12.3
  void moveToLocation(Location location, {int? zoom}) {
    if (state is MapReady) {
      final currentState = state as MapReady;
      emit(currentState.copyWith(location: location, zoom: zoom));
      _saveMapViewState(location, zoom ?? currentState.zoom);
    }
  }

  /// Sets the map zoom level.
  ///
  /// Higher values zoom in closer, lower values zoom out.
  /// Typical range is 1-20, with 12 being a good default for city-level view.
  ///
  /// Requirements: 2.4, 12.3
  void setZoom(int zoom) {
    if (state is MapReady) {
      final currentState = state as MapReady;
      emit(currentState.copyWith(zoom: zoom));
      if (currentState.location != null) {
        _saveMapViewState(currentState.location!, zoom);
      }
    }
  }

  /// Displays a route overlay on the map.
  ///
  /// This renders the route path on the map, typically as a polyline
  /// connecting the waypoints. The route remains visible until cleared.
  ///
  /// Requirements: 5.2
  void showRoute(Route route) {
    if (state is MapReady) {
      final currentState = state as MapReady;
      emit(currentState.copyWith(routeOverlay: route));
    }
  }

  /// Clears the current route overlay from the map.
  ///
  /// This removes any displayed route, returning the map to a clean state.
  ///
  /// Requirements: 5.2
  void clearRoute() {
    if (state is MapReady) {
      final currentState = state as MapReady;
      emit(currentState.copyWith(clearRoute: true));
    }
  }

  /// Updates both location and route simultaneously.
  ///
  /// This is useful when starting navigation to both center the map
  /// on the route and display the route overlay.
  void updateLocationAndRoute(Location location, Route route, {int? zoom}) {
    if (state is MapReady) {
      final currentState = state as MapReady;
      emit(currentState.copyWith(
        location: location,
        routeOverlay: route,
        zoom: zoom,
      ));
      _saveMapViewState(location, zoom ?? currentState.zoom);
    }
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
        if (state is MapReady) {
          final currentState = state as MapReady;
          emit(currentState.copyWith(
            location: savedState.location,
            zoom: savedState.zoom,
          ));
        }
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
  Future<void> _saveMapViewState(Location location, int zoom) async {
    if (_saveMapViewStateUseCase == null) return;

    try {
      await _saveMapViewStateUseCase.execute(
        location: location,
        zoom: zoom,
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

  /// Builds a route to the specified destination and prepares for navigation.
  ///
  /// This method:
  /// 1. Calls the native engine to build a route
  /// 2. Waits briefly for route calculation
  /// 3. Returns the map controller for navigation start
  ///
  /// The caller should then dispatch StartNavigation event with the returned controller.
  ///
  /// Requirements: 6.1
  Future<AgusMapController> buildRouteAndPrepareNavigation(
    double lat,
    double lon,
  ) async {
    _logger.info('Building route to lat=$lat, lon=$lon');
    
    // Call native to build route
    // The native code will automatically activate navigation mode when route is ready
    await mapController.buildRoute(lat, lon);
    
    // Wait briefly for route calculation to complete
    // The native listener will automatically call FollowRoute() when ready
    await Future.delayed(const Duration(milliseconds: 1500));
    
    _logger.info('Route build completed, navigation mode will be activated automatically');
    return mapController;
  }
}

