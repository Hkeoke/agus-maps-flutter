import 'dart:async';
import 'dart:math' as math;
import 'package:agus_maps_flutter/agus_maps_flutter.dart';
import 'package:rikera_app/core/utils/logger.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/domain/repositories/navigation_repository.dart';

/// Implementation of [NavigationRepository] for managing navigation sessions.
///
/// This repository uses the native CoMaps navigation engine to track user
/// progress along a route, detects off-route conditions, calculates distances
/// to turns and destination, and manages the navigation session lifecycle.
///
/// Requirements: 6.1, 6.4, 6.5, 6.7
class NavigationRepositoryImpl implements NavigationRepository {
  final AppLogger _logger = const AppLogger('NavigationRepository');
  AgusMapController? _mapController;

  /// The currently active route, or null if not navigating.
  Route? _currentRoute;

  /// The current location of the user.
  Location? _currentLocation;

  /// Whether a navigation session is currently active.
  bool _isNavigating = false;

  /// Stream controller for navigation state updates.
  final StreamController<NavigationState> _navigationStateController =
      StreamController<NavigationState>.broadcast();

  /// Timer for polling navigation state from native engine.
  Timer? _navigationPollTimer;
  StreamSubscription<RoutingEvent>? _routingEventSubscription;

  /// Polling interval for navigation updates (milliseconds).
  static const int _pollIntervalMs = 1000;

  NavigationRepositoryImpl();

  /// Sets the map controller for navigation operations.
  void setMapController(AgusMapController controller) {
    _mapController = controller;
  }

  @override
  Future<void> startNavigation(Route route) async {
    try {
      _logger.info('Starting navigation session');
      _currentRoute = route;
      _isNavigating = true;

      // Activate route following mode in native engine
      // This tells the native code that navigation is active, which affects:
      // - My Position mode cycling (will use FOLLOW_AND_ROTATE in navigation)
      // - Auto-zoom behavior
      // - Route following logic
      if (_mapController != null) {
        await _mapController!.followRoute();
        _logger.info('Route following mode activated in native engine');

        // Listen to routing events for recalculation triggers
        _routingEventSubscription?.cancel();
        _routingEventSubscription = _mapController!.onRoutingEvent.listen(_handleRoutingEvent);
      } else {
        _logger.warning('Map controller not available, navigation mode not activated');
      }

      // Start polling navigation state from native engine
      _startNavigationPolling();

      _logger.info('Navigation session started successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to start navigation',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Starts periodic polling of navigation state from native engine.
  void _startNavigationPolling() {
    _navigationPollTimer?.cancel();
    _navigationPollTimer = Timer.periodic(
      const Duration(milliseconds: _pollIntervalMs),
      (_) => _pollNavigationState(),
    );
  }

  @override
  Future<void> stopNavigation() async {
    try {
      _logger.info('Stopping navigation session');
      
      // Stop polling
      _navigationPollTimer?.cancel();
      _navigationPollTimer = null;
      
      _routingEventSubscription?.cancel();
      _routingEventSubscription = null;
      
      // Deactivate route following mode in native engine
      // This tells the native code that navigation is no longer active
      if (_mapController != null) {
        await _mapController!.disableFollowing();
        _logger.info('Route following mode deactivated in native engine');
      }
      
      _isNavigating = false;
      _currentRoute = null;
      _currentLocation = null;
      
      _logger.info('Navigation session stopped');
    } catch (e, stackTrace) {
      _logger.error(
        'Error stopping navigation',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Stream<NavigationState> getNavigationState() {
    return _navigationStateController.stream;
  }

  @override
  Future<void> updateLocation(Location location) async {
    try {
      if (!_isNavigating || _currentRoute == null) {
        return;
      }

      _currentLocation = location;
      
      // Location updates are sent to native via MapCubit's setMyPosition
      // The native engine handles route following internally
      // We just poll the state via _pollNavigationState
    } catch (e, stackTrace) {
      _logger.error(
        'Error updating navigation location',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Polls navigation state from the native CoMaps engine.
  Future<void> _pollNavigationState() async {
    try {
      if (!_isNavigating || _currentRoute == null || _currentLocation == null || _mapController == null) {
        return;
      }

      // Check if route is finished
      final isFinished = await _mapController!.isRouteFinished();
      if (isFinished) {
        _logger.info('Route finished - arrived at destination');
        await stopNavigation();
        
        // Emit final state with zero distances
        _emitNavigationState(
          currentSegment: null,
          nextSegment: null,
          distanceToNextTurnMeters: 0,
          remainingDistanceMeters: 0,
          remainingTimeSeconds: 0,
          isOffRoute: false,
          turnDirection: TurnDirection.destination,
        );
        return;
      }

      // Get route following info from native
      final routeInfo = await _mapController!.getRouteFollowingInfo();
      if (routeInfo == null) {
        _logger.warning('No route following info available from native');
        return;
      }

      // Parse native route info
      final distanceToTarget = (routeInfo['distanceToTarget'] as num?)?.toDouble() ?? 0.0;
      final timeToTarget = (routeInfo['timeToTarget'] as num?)?.toInt() ?? 0;
      final distanceToTurn = (routeInfo['distanceToTurn'] as num?)?.toDouble() ?? 0.0;
      final turnInt = (routeInfo['turn'] as num?)?.toInt() ?? 0;
      final nextTurnInt = (routeInfo['nextTurn'] as num?)?.toInt() ?? 0;
      final speedLimitMps = (routeInfo['speedLimitMps'] as num?)?.toDouble() ?? 0.0;
      final currentStreet = routeInfo['currentStreetName'] as String?;
      final nextStreet = routeInfo['nextStreetName'] as String?;

      // Map native turn to TurnDirection
      final turnDirection = _mapNativeTurnToTurnDirection(turnInt);

      // Emit navigation state with native data
      _emitNavigationState(
        currentSegment: null, // Segments are not strictly needed if we have turn info
        nextSegment: null,
        distanceToNextTurnMeters: distanceToTurn,
        remainingDistanceMeters: distanceToTarget,
        remainingTimeSeconds: timeToTarget,
        isOffRoute: false,
        currentStreetName: currentStreet,
        nextStreetName: nextStreet,
        turnDirection: turnDirection,
        speedLimitMetersPerSecond: speedLimitMps > 0 ? speedLimitMps : null,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Error polling navigation state',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Maps native CarDirection integer to [TurnDirection] enum.
  TurnDirection _mapNativeTurnToTurnDirection(int nativeTurn) {
    switch (nativeTurn) {
      case 1: return TurnDirection.straight;
      case 2: return TurnDirection.slightLeft;
      case 3: return TurnDirection.left;
      case 4: return TurnDirection.sharpLeft;
      case 5: return TurnDirection.uTurnLeft;
      case 6: return TurnDirection.slightRight;
      case 7: return TurnDirection.right;
      case 8: return TurnDirection.sharpRight;
      case 9:
      case 10: return TurnDirection.roundabout;
      case 11:
      case 14: return TurnDirection.exitRoundabout;
      case 12: return TurnDirection.slightLeft;
      case 13: return TurnDirection.slightRight;
      case 15: return TurnDirection.destination;
      default: return TurnDirection.straight;
    }
  }

  @override
  bool get isNavigating => _isNavigating;

  /// Emits a navigation state update to the stream.
  void _emitNavigationState({
    required RouteSegment? currentSegment,
    required RouteSegment? nextSegment,
    required double distanceToNextTurnMeters,
    required double remainingDistanceMeters,
    required int remainingTimeSeconds,
    required bool isOffRoute,
    String? currentStreetName,
    String? nextStreetName,
    TurnDirection? turnDirection,
    double? speedLimitMetersPerSecond,
  }) {
    if (_currentRoute == null || _currentLocation == null) {
      return;
    }

    final state = NavigationState(
      route: _currentRoute!,
      currentLocation: _currentLocation!,
      currentSegment: currentSegment,
      nextSegment: nextSegment,
      distanceToNextTurnMeters: distanceToNextTurnMeters,
      remainingDistanceMeters: remainingDistanceMeters,
      remainingTimeSeconds: remainingTimeSeconds,
      isOffRoute: isOffRoute,
      currentStreetName: currentStreetName,
      nextStreetName: nextStreetName,
      turnDirection: turnDirection,
      speedLimitMetersPerSecond: speedLimitMetersPerSecond,
    );

    _navigationStateController.add(state);
  }

  /// Disposes of resources used by this repository.
  void dispose() {
    _navigationPollTimer?.cancel();
    _navigationStateController.close();
  }

  void _handleRoutingEvent(RoutingEvent event) {
    if (event.type == RoutingEvent.rebuildStarted) {
      _logger.info('Received route rebuild recommendation from native engine (off-route detected)');
      _rebuildRoute();
    }
  }

  Future<void> _rebuildRoute() async {
    if (_currentRoute == null || _mapController == null) {
      _logger.warning('Cannot rebuild route: no current route or controller');
      return;
    }

    try {
      // The route waypoints list should contain at least origin and destination
      // We want to rebuild to the original destination
      if (_currentRoute!.waypoints.isNotEmpty) {
        final dest = _currentRoute!.waypoints.last;
        _logger.info('Rebuilding route to destination: ${dest.latitude}, ${dest.longitude}');
        
        // This will trigger a route rebuild from current position to destination
        await _mapController!.buildRoute(dest.latitude, dest.longitude);
      } else {
        _logger.warning('Cannot rebuild route: waypoints list is empty');
      }
    } catch (e) {
      _logger.error('Failed to rebuild route', error: e);
    }
  }
}
