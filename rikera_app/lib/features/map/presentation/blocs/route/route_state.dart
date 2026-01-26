import 'package:rikera_app/features/map/domain/entities/entities.dart';

/// Base class for route states.
abstract class RouteState {
  const RouteState();
}

/// Initial state before any route has been calculated.
class RouteInitial extends RouteState {
  const RouteInitial();

  @override
  bool operator ==(Object other) => other is RouteInitial;

  @override
  int get hashCode => 0;
}

/// State when a route is being calculated.
///
/// This state is emitted while the routing engine is computing the route.
///
/// Requirements: 5.1
class RouteCalculating extends RouteState {
  final Location origin;
  final Location destination;

  const RouteCalculating({required this.origin, required this.destination});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RouteCalculating &&
        other.origin == origin &&
        other.destination == destination;
  }

  @override
  int get hashCode => origin.hashCode ^ destination.hashCode;

  @override
  String toString() =>
      'RouteCalculating(origin: $origin, destination: $destination)';
}

/// State when a route has been successfully calculated.
///
/// This state contains the calculated route with all waypoints, segments,
/// distance, and time information.
///
/// Requirements: 5.1, 5.2, 5.3
class RouteCalculated extends RouteState {
  final Route route;

  const RouteCalculated(this.route);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RouteCalculated && other.route == route;
  }

  @override
  int get hashCode => route.hashCode;

  @override
  String toString() => 'RouteCalculated($route)';
}

/// State when route calculation fails.
///
/// This state contains an error message explaining why the calculation failed
/// (e.g., no map data, destination unreachable).
///
/// Requirements: 5.6
class RouteError extends RouteState {
  final String message;

  const RouteError(this.message);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RouteError && other.message == message;
  }

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'RouteError($message)';
}
