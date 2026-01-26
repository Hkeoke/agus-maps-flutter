import 'package:rikera_app/core/utils/result.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/domain/repositories/repositories.dart';

/// Use case for calculating a route from origin to destination.
///
/// This use case enforces vehicle mode routing for all route calculations,
/// ensuring routes are optimized for car/vehicle driving (not pedestrian).
///
/// Requirements: 5.1, 2.3
class CalculateRouteUseCase {
  final RouteRepository _repository;

  const CalculateRouteUseCase(this._repository);

  /// Calculates a route from [origin] to [destination].
  ///
  /// The routing mode is always set to [RoutingMode.vehicle] to ensure
  /// routes are optimized for car navigation.
  ///
  /// Returns a [Result] containing the calculated [Route] on success,
  /// or an error if calculation fails (e.g., no map data, unreachable destination).
  ///
  /// Requirements: 5.1, 2.3
  Future<Result<Route>> execute({
    required Location origin,
    required Location destination,
  }) async {
    // Always use vehicle mode for this car navigation app
    return await _repository.calculateRoute(
      origin: origin,
      destination: destination,
      mode: RoutingMode.vehicle,
    );
  }
}
