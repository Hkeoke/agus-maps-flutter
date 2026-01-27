import 'package:rikera_app/core/utils/result.dart';
import 'package:rikera_app/core/errors/app_errors.dart';
import 'package:rikera_app/core/utils/logger.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/domain/repositories/route_repository.dart';
import 'package:rikera_app/features/map/data/datasources/map_engine_datasource.dart';
import 'package:rikera_app/features/map/data/datasources/map_engine_exception.dart';

/// Implementation of [RouteRepository] using the CoMaps routing engine.
///
/// This repository calculates routes optimized for vehicle driving using
/// offline map data. It caches calculated routes with expiration and size limits
/// to optimize performance while managing memory usage.
///
/// Requirements: 5.1, 6.5
class RouteRepositoryImpl implements RouteRepository {
  final MapEngineDataSource _mapEngineDataSource;
  final AppLogger _logger = const AppLogger('RouteRepository');

  /// Cache for calculated routes, keyed by origin-destination pair.
  /// Each entry includes the route and its creation timestamp.
  final Map<String, _CachedRoute> _routeCache = {};

  /// Maximum number of routes to keep in cache.
  /// This prevents unbounded memory growth.
  static const int _maxCacheSize = 50;

  /// Duration after which cached routes expire (30 minutes).
  /// Routes expire to ensure they reflect current map data and conditions.
  static const Duration _cacheExpiration = Duration(minutes: 30);

  RouteRepositoryImpl({required MapEngineDataSource mapEngineDataSource})
    : _mapEngineDataSource = mapEngineDataSource;

  @override
  Future<Result<Route>> calculateRoute({
    required Location origin,
    required Location destination,
    required RoutingMode mode,
  }) async {
    try {
      _logger.info(
        'Calculating route from ${origin.latitude},${origin.longitude} to ${destination.latitude},${destination.longitude}',
      );

      // Ensure we're always using vehicle mode for this app
      if (mode != RoutingMode.vehicle) {
        _logger.warning('Non-vehicle routing mode requested: $mode');
        return Result.failure(
          RoutingError.calculationFailed(
            'Only vehicle routing mode is supported',
          ),
        );
      }

      // Check cache first
      final cacheKey = _getCacheKey(origin, destination);
      final cachedRoute = _getFromCache(cacheKey);
      if (cachedRoute != null) {
        _logger.debug('Returning cached route');
        return Result.success(cachedRoute);
      }

      // TODO: Implement actual route calculation using agus_maps_flutter
      // For now, return a placeholder error indicating the feature needs implementation
      // This will be implemented when agus_maps_flutter exposes routing APIs
      _logger.warning('Route calculation not yet implemented');
      return Result.failure(GenericError.notImplemented());

      // Future implementation will look like:
      // final route = await _mapEngineDataSource.calculateRoute(
      //   originLat: origin.latitude,
      //   originLon: origin.longitude,
      //   destLat: destination.latitude,
      //   destLon: destination.longitude,
      //   mode: mode,
      // );
      //
      // // Cache the calculated route
      // _addToCache(cacheKey, route);
      //
      // return Result.success(route);
    } on MapEngineException catch (e, stackTrace) {
      _logger.error(
        'Route calculation failed with MapEngineException',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(RoutingError.calculationFailed(e.message));
    } catch (e, stackTrace) {
      _logger.error(
        'Route calculation failed',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(RoutingError.calculationFailed('$e'));
    }
  }

  @override
  Future<Result<Route>> recalculateRoute({
    required Route originalRoute,
    required Location currentLocation,
  }) async {
    try {
      _logger.info('Recalculating route from current location');

      // Get the original destination from the route
      if (originalRoute.waypoints.isEmpty) {
        _logger.error('Original route has no waypoints');
        return Result.failure(
          RoutingError.calculationFailed('Original route has no waypoints'),
        );
      }

      final destination = originalRoute.waypoints.last;

      // Calculate a new route from current location to original destination
      return await calculateRoute(
        origin: currentLocation,
        destination: destination,
        mode: RoutingMode.vehicle,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Route recalculation failed',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(RoutingError.calculationFailed('$e'));
    }
  }

  /// Generates a cache key for a route based on origin and destination.
  ///
  /// The key is formatted as "lat1,lon1->lat2,lon2" with coordinates
  /// rounded to 6 decimal places (approximately 0.1 meter precision).
  String _getCacheKey(Location origin, Location destination) {
    final originKey =
        '${origin.latitude.toStringAsFixed(6)},${origin.longitude.toStringAsFixed(6)}';
    final destKey =
        '${destination.latitude.toStringAsFixed(6)},${destination.longitude.toStringAsFixed(6)}';
    return '$originKey->$destKey';
  }

  /// Retrieves a route from cache if it exists and hasn't expired.
  ///
  /// Returns null if the route is not in cache or has expired.
  Route? _getFromCache(String cacheKey) {
    final cachedRoute = _routeCache[cacheKey];
    if (cachedRoute == null) {
      return null;
    }

    // Check if the cached route has expired
    final now = DateTime.now();
    if (now.difference(cachedRoute.timestamp) > _cacheExpiration) {
      _logger.debug('Cached route expired, removing from cache');
      _routeCache.remove(cacheKey);
      return null;
    }

    return cachedRoute.route;
  }

  /// Adds a route to the cache with the current timestamp.
  ///
  /// If the cache is full, removes the oldest entry before adding the new one.
  void _addToCache(String cacheKey, Route route) {
    // If cache is full, remove the oldest entry
    if (_routeCache.length >= _maxCacheSize) {
      _removeOldestCacheEntry();
    }

    _routeCache[cacheKey] = _CachedRoute(
      route: route,
      timestamp: DateTime.now(),
    );
    _logger.debug('Route added to cache (cache size: ${_routeCache.length})');
  }

  /// Removes the oldest entry from the cache based on timestamp.
  void _removeOldestCacheEntry() {
    if (_routeCache.isEmpty) return;

    String? oldestKey;
    DateTime? oldestTime;

    for (final entry in _routeCache.entries) {
      if (oldestTime == null || entry.value.timestamp.isBefore(oldestTime)) {
        oldestKey = entry.key;
        oldestTime = entry.value.timestamp;
      }
    }

    if (oldestKey != null) {
      _routeCache.remove(oldestKey);
      _logger.debug('Removed oldest cache entry');
    }
  }

  /// Clears the route cache.
  ///
  /// This can be called to free memory or when map data is updated.
  void clearCache() {
    final size = _routeCache.length;
    _routeCache.clear();
    _logger.info('Route cache cleared ($size entries removed)');
  }

  /// Gets cache statistics for monitoring.
  ///
  /// Returns a map with cache size and hit rate information.
  Map<String, dynamic> getCacheStats() {
    return {
      'size': _routeCache.length,
      'maxSize': _maxCacheSize,
      'expirationMinutes': _cacheExpiration.inMinutes,
    };
  }
}

/// Internal class to store cached routes with their creation timestamp.
class _CachedRoute {
  final Route route;
  final DateTime timestamp;

  _CachedRoute({required this.route, required this.timestamp});
}
