import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rikera_app/features/map/domain/usecases/usecases.dart';
import 'route_event.dart';
import 'route_state.dart';

/// Bloc for managing route calculation.
///
/// This bloc handles:
/// - Calculating routes from origin to destination
/// - Recalculating routes when going off-route
/// - Clearing routes
/// - Error handling for route calculation failures
///
/// Requirements: 5.1, 5.6
class RouteBloc extends Bloc<RouteEvent, RouteState> {
  final CalculateRouteUseCase _calculateRouteUseCase;

  RouteBloc({required CalculateRouteUseCase calculateRouteUseCase})
    : _calculateRouteUseCase = calculateRouteUseCase,
      super(const RouteInitial()) {
    on<CalculateRoute>(_onCalculateRoute);
    on<RecalculateRoute>(_onRecalculateRoute);
    on<ClearRoute>(_onClearRoute);
  }

  /// Handles the CalculateRoute event.
  ///
  /// This calculates a route from the origin to destination using the
  /// CalculateRouteUseCase, which enforces vehicle mode routing.
  ///
  /// Requirements: 5.1
  Future<void> _onCalculateRoute(
    CalculateRoute event,
    Emitter<RouteState> emit,
  ) async {
    // Emit calculating state
    emit(
      RouteCalculating(origin: event.origin, destination: event.destination),
    );

    try {
      // Calculate route using the use case
      final result = await _calculateRouteUseCase.execute(
        origin: event.origin,
        destination: event.destination,
      );

      // Handle result
      if (result.isSuccess) {
        emit(RouteCalculated(result.valueOrNull!));
      } else {
        emit(RouteError(result.errorOrNull?.message ?? 'Unknown error'));
      }
    } catch (e) {
      emit(RouteError('Failed to calculate route: $e'));
    }
  }

  /// Handles the RecalculateRoute event.
  ///
  /// This recalculates a route from the current location to the original
  /// destination. This is typically used when the user goes off-route.
  ///
  /// Requirements: 6.5
  Future<void> _onRecalculateRoute(
    RecalculateRoute event,
    Emitter<RouteState> emit,
  ) async {
    // Get the original destination from the route
    final destination = event.originalRoute.waypoints.last;

    // Emit calculating state
    emit(
      RouteCalculating(origin: event.currentLocation, destination: destination),
    );

    try {
      // Calculate new route from current location to destination
      final result = await _calculateRouteUseCase.execute(
        origin: event.currentLocation,
        destination: destination,
      );

      // Handle result
      if (result.isSuccess) {
        emit(RouteCalculated(result.valueOrNull!));
      } else {
        emit(RouteError(result.errorOrNull?.message ?? 'Unknown error'));
      }
    } catch (e) {
      emit(RouteError('Failed to recalculate route: $e'));
    }
  }

  /// Handles the ClearRoute event.
  ///
  /// This clears the current route and returns to the initial state.
  Future<void> _onClearRoute(ClearRoute event, Emitter<RouteState> emit) async {
    emit(const RouteInitial());
  }
}
