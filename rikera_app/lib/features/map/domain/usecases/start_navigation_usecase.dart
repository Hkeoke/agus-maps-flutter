import 'package:rikera_app/core/errors/app_errors.dart';
import 'package:rikera_app/core/utils/result.dart';
import 'package:rikera_app/features/map/domain/entities/entities.dart';
import 'package:rikera_app/features/map/domain/repositories/repositories.dart';

/// Use case for starting a navigation session.
///
/// This use case initializes a navigation session with the given route,
/// enabling location tracking, screen wake lock, and voice guidance by default.
///
/// Requirements: 6.1, 14.1
class StartNavigationUseCase {
  final NavigationRepository _navigationRepository;
  final LocationRepository _locationRepository;

  const StartNavigationUseCase(
    this._navigationRepository,
    this._locationRepository,
  );

  /// Starts navigation for the given [route].
  ///
  /// This method:
  /// 1. Checks if location permissions are granted
  /// 2. Starts the navigation session with the route
  /// 3. Enables location tracking
  /// 4. Activates screen wake lock
  /// 5. Enables voice guidance by default
  ///
  /// Returns a [Result] indicating success or failure.
  /// If location permissions are not granted, returns an error.
  ///
  /// Requirements: 6.1, 14.1
  Future<Result<void>> execute(Route route) async {
    try {
      // Check if location permissions are granted
      final hasPermissions = await _locationRepository.hasPermissions();
      if (!hasPermissions) {
        return Result.failure(LocationError.permissionDenied());
      }

      // Start the navigation session
      // The NavigationRepository handles:
      // - Setting isNavigating = true
      // - Enabling screen wake lock
      // - Enabling voice guidance by default
      // - Starting location tracking
      await _navigationRepository.startNavigation(route);

      return Result.success(null);
    } catch (e, stackTrace) {
      return Result.failure(
        GenericError.unknown('Failed to start navigation: $e', stackTrace),
      );
    }
  }
}
