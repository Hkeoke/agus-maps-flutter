import 'package:rikera_app/features/map/domain/entities/entities.dart';

/// Repository interface for navigation session management.
///
/// This repository handles active navigation sessions, tracking user progress
/// along a route, detecting off-route conditions, and managing navigation state.
///
/// Requirements: 6.1, 6.7
abstract class NavigationRepository {
  /// Starts a navigation session for the given route.
  ///
  /// This initializes the navigation state, enables location tracking,
  /// activates screen wake lock, and enables voice guidance by default.
  ///
  /// Requirements: 6.1
  Future<void> startNavigation(Route route);

  /// Stops the current navigation session.
  ///
  /// This ends the navigation, releases the screen wake lock,
  /// and stops voice guidance.
  ///
  /// Requirements: 6.7
  Future<void> stopNavigation();

  /// Returns a stream of navigation state updates.
  ///
  /// The stream emits [NavigationState] objects as the user progresses
  /// along the route, including:
  /// - Current location and segment
  /// - Distance to next turn and destination
  /// - Off-route detection
  /// - Arrival detection
  ///
  /// The stream is active only during a navigation session.
  ///
  /// Requirements: 6.1, 6.7
  Stream<NavigationState> getNavigationState();

  /// Updates the navigation state with a new location.
  ///
  /// This method processes location updates to:
  /// - Calculate progress along the route
  /// - Detect turn completion and advance to next segment
  /// - Detect off-route conditions
  /// - Detect arrival at destination
  /// - Trigger voice guidance at appropriate points
  ///
  /// Requirements: 6.1
  Future<void> updateLocation(Location location);

  /// Returns true if a navigation session is currently active.
  ///
  /// Requirements: 6.1
  bool get isNavigating;
}
