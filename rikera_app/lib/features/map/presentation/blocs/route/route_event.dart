import 'package:rikera_app/features/map/domain/entities/entities.dart';

/// Base class for route events.
abstract class RouteEvent {
  const RouteEvent();
}

/// Event to calculate a route from origin to destination.
///
/// This event triggers route calculation using the CoMaps routing engine.
///
/// Requirements: 5.1
class CalculateRoute extends RouteEvent {
  final Location origin;
  final Location destination;

  const CalculateRoute({required this.origin, required this.destination});
}

/// Event to recalculate the current route.
///
/// This is typically triggered when the user goes off-route and needs
/// a new route from their current location to the original destination.
///
/// Requirements: 6.5
class RecalculateRoute extends RouteEvent {
  final Route originalRoute;
  final Location currentLocation;

  const RecalculateRoute({
    required this.originalRoute,
    required this.currentLocation,
  });
}

/// Event to clear the current route.
///
/// This removes the calculated route from state.
class ClearRoute extends RouteEvent {
  const ClearRoute();
}
