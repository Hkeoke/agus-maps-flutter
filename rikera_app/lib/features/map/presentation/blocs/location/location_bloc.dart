import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rikera_app/features/map/domain/usecases/usecases.dart';
import 'location_event.dart';
import 'location_state.dart';

/// Bloc for managing location tracking.
///
/// This bloc handles:
/// - Starting and stopping location tracking
/// - Requesting location permissions
/// - Processing location updates
/// - Handling permission denial
///
/// Requirements: 4.1, 4.2, 13.2
class LocationBloc extends Bloc<LocationEvent, LocationState> {
  final TrackLocationUseCase _trackLocationUseCase;

  StreamSubscription? _locationSubscription;

  LocationBloc({required TrackLocationUseCase trackLocationUseCase})
    : _trackLocationUseCase = trackLocationUseCase,
      super(const LocationIdle()) {
    on<StartTracking>(_onStartTracking);
    on<StopTracking>(_onStopTracking);
    on<LocationUpdated>(_onLocationUpdated);
    on<RequestPermissions>(_onRequestPermissions);
  }

  /// Handles the StartTracking event.
  ///
  /// This checks for location permissions and starts the location stream
  /// if permissions are granted.
  ///
  /// Requirements: 4.1, 4.2
  Future<void> _onStartTracking(
    StartTracking event,
    Emitter<LocationState> emit,
  ) async {
    try {
      // Check if permissions are granted
      final hasPermissions = await _trackLocationUseCase.hasPermissions();

      if (!hasPermissions) {
        emit(const LocationPermissionDenied());
        return;
      }

      // Start location stream
      _locationSubscription = _trackLocationUseCase.execute().listen(
        (location) {
          add(LocationUpdated(location));
        },
        onError: (error) {
          emit(LocationError('Location tracking error: $error'));
        },
      );
    } catch (e) {
      emit(LocationError('Failed to start location tracking: $e'));
    }
  }

  /// Handles the StopTracking event.
  ///
  /// This stops the location stream and returns to idle state.
  Future<void> _onStopTracking(
    StopTracking event,
    Emitter<LocationState> emit,
  ) async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    emit(const LocationIdle());
  }

  /// Handles the LocationUpdated event.
  ///
  /// This updates the state with the new location data.
  ///
  /// Requirements: 4.2
  Future<void> _onLocationUpdated(
    LocationUpdated event,
    Emitter<LocationState> emit,
  ) async {
    emit(LocationTracking(event.location));
  }

  /// Handles the RequestPermissions event.
  ///
  /// This requests location permissions from the user and starts tracking
  /// if permissions are granted.
  ///
  /// Requirements: 4.1, 13.2
  Future<void> _onRequestPermissions(
    RequestPermissions event,
    Emitter<LocationState> emit,
  ) async {
    emit(const LocationRequestingPermission());

    try {
      final granted = await _trackLocationUseCase.requestPermissions();

      if (granted) {
        // Permissions granted, start tracking
        add(const StartTracking());
      } else {
        // Permissions denied
        emit(
          const LocationPermissionDenied(
            message:
                'Location permission denied. Please enable location access in settings to use navigation features.',
          ),
        );
      }
    } catch (e) {
      emit(LocationError('Failed to request permissions: $e'));
    }
  }

  @override
  Future<void> close() async {
    await _locationSubscription?.cancel();
    return super.close();
  }
}
