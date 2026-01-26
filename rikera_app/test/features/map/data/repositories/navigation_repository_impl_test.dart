import 'package:flutter_test/flutter_test.dart';
import 'package:rikera_app/features/map/data/repositories/navigation_repository_impl.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';

void main() {
  group('NavigationRepositoryImpl', () {
    late NavigationRepositoryImpl repository;

    setUp(() {
      repository = NavigationRepositoryImpl();
    });

    tearDown(() {
      repository.dispose();
    });

    test('should start with isNavigating false', () {
      expect(repository.isNavigating, isFalse);
    });

    test('should set isNavigating to true when navigation starts', () async {
      final route = _createTestRoute();
      await repository.startNavigation(route);

      expect(repository.isNavigating, isTrue);
    });

    test('should set isNavigating to false when navigation stops', () async {
      final route = _createTestRoute();
      await repository.startNavigation(route);
      await repository.stopNavigation();

      expect(repository.isNavigating, isFalse);
    });

    test('should emit navigation state when location is updated', () async {
      final route = _createTestRoute();
      await repository.startNavigation(route);

      final stateStream = repository.getNavigationState();
      final stateFuture = stateStream.first;

      final location = Location(
        latitude: 36.14,
        longitude: -5.35,
        timestamp: DateTime.now(),
      );

      await repository.updateLocation(location);

      final state = await stateFuture;
      expect(state.currentLocation, equals(location));
      expect(state.route, equals(route));
    });

    test('should detect arrival at destination', () async {
      final route = _createTestRoute();
      await repository.startNavigation(route);

      // Move to destination
      final destination = route.waypoints.last;
      await repository.updateLocation(destination);

      // Should stop navigation when arrived
      expect(repository.isNavigating, isFalse);
    });

    test('should advance to next segment when passing turn', () async {
      final route = _createTestRoute();
      await repository.startNavigation(route);

      final stateStream = repository.getNavigationState();
      final states = <NavigationState>[];
      final subscription = stateStream.listen(states.add);

      // Move through first segment
      final firstSegmentEnd = route.segments[0].end;
      await repository.updateLocation(firstSegmentEnd);

      await Future.delayed(const Duration(milliseconds: 100));
      await subscription.cancel();

      // Should have advanced to next segment
      expect(states.isNotEmpty, isTrue);
    });

    test('should calculate remaining distance correctly', () async {
      final route = _createTestRoute();
      await repository.startNavigation(route);

      final stateStream = repository.getNavigationState();
      final stateFuture = stateStream.first;

      final location = Location(
        latitude: 36.14,
        longitude: -5.35,
        timestamp: DateTime.now(),
      );

      await repository.updateLocation(location);

      final state = await stateFuture;
      expect(state.remainingDistanceMeters, greaterThan(0));
    });

    test('should calculate remaining time correctly', () async {
      final route = _createTestRoute();
      await repository.startNavigation(route);

      final stateStream = repository.getNavigationState();
      final stateFuture = stateStream.first;

      final location = Location(
        latitude: 36.14,
        longitude: -5.35,
        speed: 13.89, // 50 km/h in m/s
        timestamp: DateTime.now(),
      );

      await repository.updateLocation(location);

      final state = await stateFuture;
      expect(state.remainingTimeSeconds, greaterThan(0));
    });
  });
}

/// Creates a test route for Gibraltar area.
Route _createTestRoute() {
  final start = Location(
    latitude: 36.14,
    longitude: -5.35,
    timestamp: DateTime.now(),
  );

  final middle = Location(
    latitude: 36.145,
    longitude: -5.355,
    timestamp: DateTime.now(),
  );

  final end = Location(
    latitude: 36.15,
    longitude: -5.36,
    timestamp: DateTime.now(),
  );

  final segment1 = RouteSegment(
    start: start,
    end: middle,
    turnDirection: TurnDirection.straight,
    distanceMeters: 500,
    streetName: 'Main Street',
  );

  final segment2 = RouteSegment(
    start: middle,
    end: end,
    turnDirection: TurnDirection.left,
    distanceMeters: 600,
    streetName: 'Second Street',
  );

  return Route(
    waypoints: [start, middle, end],
    totalDistanceMeters: 1100,
    estimatedTimeSeconds: 120,
    segments: [segment1, segment2],
    bounds: RouteBounds(
      minLatitude: 36.14,
      maxLatitude: 36.15,
      minLongitude: -5.36,
      maxLongitude: -5.35,
    ),
  );
}
