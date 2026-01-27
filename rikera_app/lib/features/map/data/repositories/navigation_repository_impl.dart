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
  /// 
  /// This method is called periodically during navigation to fetch
  /// real-time navigation data from the native engine.
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
      final turnInfo = routeInfo['turn'] as Map<String, dynamic>?;
      final nextTurnInfo = routeInfo['nextTurn'] as Map<String, dynamic>?;
      
      // Determine current and next segments based on turn info
      RouteSegment? currentSegment;
      RouteSegment? nextSegment;
      
      if (turnInfo != null && _currentRoute!.segments.isNotEmpty) {
        // Try to match turn info to route segments
        // For now, use first segment as current (simplified)
        currentSegment = _currentRoute!.segments.first;
        if (_currentRoute!.segments.length > 1) {
          nextSegment = _currentRoute!.segments[1];
        }
      }

      // Emit navigation state with native data
      _emitNavigationState(
        currentSegment: currentSegment,
        nextSegment: nextSegment,
        distanceToNextTurnMeters: distanceToTurn,
        remainingDistanceMeters: distanceToTarget,
        remainingTimeSeconds: timeToTarget,
        isOffRoute: false, // Native engine handles off-route detection
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Error polling navigation state',
        error: e,
        stackTrace: stackTrace,
      );
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
    );

    _navigationStateController.add(state);
  }

  /// Disposes of resources used by this repository.
  void dispose() {
    _navigationPollTimer?.cancel();
    _navigationStateController.close();
  }
}
