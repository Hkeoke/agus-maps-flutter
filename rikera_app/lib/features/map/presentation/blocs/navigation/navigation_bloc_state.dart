import 'package:rikera_app/features/map/domain/entities/entities.dart';

/// Base class for navigation states.
abstract class NavigationBlocState {
  const NavigationBlocState();
}

/// Initial state before navigation has started.
///
/// This is the default state when no navigation session is active.
class NavigationIdle extends NavigationBlocState {
  const NavigationIdle();

  @override
  bool operator ==(Object other) => other is NavigationIdle;

  @override
  int get hashCode => 0;
}

/// State when navigation is actively running.
///
/// This state contains the current navigation information including
/// route progress, turn instructions, and distances.
///
/// Requirements: 6.1, 6.2, 6.3, 6.4
class NavigationNavigating extends NavigationBlocState {
  final NavigationState navigationState;

  const NavigationNavigating(this.navigationState);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NavigationNavigating &&
        other.navigationState == navigationState;
  }

  @override
  int get hashCode => navigationState.hashCode;

  @override
  String toString() => 'NavigationNavigating($navigationState)';
}

/// State when the user has deviated from the route.
///
/// This state indicates that automatic rerouting is needed.
/// The navigation state still contains the original route and current location.
///
/// Requirements: 6.5
class NavigationOffRoute extends NavigationBlocState {
  final NavigationState navigationState;

  const NavigationOffRoute(this.navigationState);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NavigationOffRoute &&
        other.navigationState == navigationState;
  }

  @override
  int get hashCode => navigationState.hashCode;

  @override
  String toString() => 'NavigationOffRoute($navigationState)';
}

/// State when the user has arrived at the destination.
///
/// This state indicates that the navigation session has completed successfully.
///
/// Requirements: 6.7
class NavigationArrived extends NavigationBlocState {
  final Location destination;

  const NavigationArrived(this.destination);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NavigationArrived && other.destination == destination;
  }

  @override
  int get hashCode => destination.hashCode;

  @override
  String toString() => 'NavigationArrived($destination)';
}

/// State when navigation encounters an error.
class NavigationError extends NavigationBlocState {
  final String message;

  const NavigationError(this.message);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NavigationError && other.message == message;
  }

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'NavigationError($message)';
}
