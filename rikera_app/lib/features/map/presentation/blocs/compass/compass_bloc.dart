import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rikera_app/core/services/compass_service.dart';
import 'compass_event.dart';
import 'compass_state.dart';

/// Bloc for managing compass sensor state and map rotation.
class CompassBloc extends Bloc<CompassEvent, CompassState> {
  final CompassService _compassService;
  StreamSubscription<double>? _headingSubscription;

  CompassBloc({
    required CompassService compassService,
  })  : _compassService = compassService,
        super(const CompassInitial()) {
    on<StartCompass>(_onStartCompass);
    on<StopCompass>(_onStopCompass);
    on<CompassHeadingUpdated>(_onCompassHeadingUpdated);
    on<ToggleCompassRotation>(_onToggleCompassRotation);
  }

  Future<void> _onStartCompass(
    StartCompass event,
    Emitter<CompassState> emit,
  ) async {
    try {
      await _compassService.start();
      
      // Subscribe to heading updates
      _headingSubscription = _compassService.headingStream.listen((heading) {
        add(CompassHeadingUpdated(heading));
      });

      // Emit initial state with rotation enabled by default
      final initialHeading = _compassService.lastHeading ?? 0.0;
      emit(CompassActive(heading: initialHeading, rotationEnabled: true));
    } catch (e) {
      emit(const CompassUnavailable());
    }
  }

  Future<void> _onStopCompass(
    StopCompass event,
    Emitter<CompassState> emit,
  ) async {
    await _headingSubscription?.cancel();
    _headingSubscription = null;
    _compassService.stop();
    emit(const CompassStopped());
  }

  void _onCompassHeadingUpdated(
    CompassHeadingUpdated event,
    Emitter<CompassState> emit,
  ) {
    if (state is CompassActive) {
      final currentState = state as CompassActive;
      emit(currentState.copyWith(heading: event.heading));
    }
  }

  void _onToggleCompassRotation(
    ToggleCompassRotation event,
    Emitter<CompassState> emit,
  ) {
    if (state is CompassActive) {
      final currentState = state as CompassActive;
      emit(currentState.copyWith(rotationEnabled: event.enabled));
    }
  }

  @override
  Future<void> close() {
    _headingSubscription?.cancel();
    _compassService.dispose();
    return super.close();
  }
}
