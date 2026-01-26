import 'package:rikera_app/core/utils/result.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';

/// Repository interface for route calculation and management.
///
/// This repository handles route planning and recalculation for vehicle navigation.
/// All routes are optimized for car/vehicle mode (not pedestrian).
///
/// Requirements: 5.1, 6.5
abstract class RouteRepository {
  /// Calculates a route from origin to destination.
  ///
  /// The route is optimized for the specified [mode] (always VehicleMode for this app).
  /// Uses offline map data for calculation.
  ///
  /// Returns a [Result] containing the calculated [Route] on success,
  /// or an error if calculation fails (e.g., no map data, unreachable destination).
  ///
  /// Requirements: 5.1
  Future<Result<Route>> calculateRoute({
    required Location origin,
    required Location destination,
    required RoutingMode mode,
  });

  /// Recalculates a route from the current location to the original destination.
  ///
  /// This is typically called when the user deviates from the original route
  /// during navigation (off-route scenario).
  ///
  /// The [originalRoute] provides context about the intended destination,
  /// and [currentLocation] is the user's current position.
  ///
  /// Returns a [Result] containing the new [Route] on success,
  /// or an error if recalculation fails.
  ///
  /// Requirements: 6.5
  Future<Result<Route>> recalculateRoute({
    required Route originalRoute,
    required Location currentLocation,
  });
}

/// Routing mode for route calculation.
///
/// For this car navigation app, only VehicleMode is used.
enum RoutingMode {
  /// Route optimized for vehicle/car driving.
  vehicle,

  /// Route optimized for pedestrian walking (not used in this app).
  pedestrian,

  /// Route optimized for bicycle (not used in this app).
  bicycle,
}
