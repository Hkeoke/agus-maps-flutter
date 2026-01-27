import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rikera_app/core/theme/theme.dart';
import 'package:rikera_app/core/utils/result.dart';
import 'package:rikera_app/core/errors/app_errors.dart';

/// Handles permission requests and provides guidance for enabling permissions.
///
/// This utility detects permission denials and provides deep links to
/// app settings where users can enable permissions.
///
/// Requirements: 13.2
class PermissionHandler {
  /// Requests location permission with user guidance.
  ///
  /// Returns a Result indicating success or failure with appropriate error.
  static Future<Result<bool>> requestLocationPermission() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return Result.failure(LocationError.serviceDisabled());
      }

      // Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();

      // If permission is denied forever, guide user to settings
      if (permission == LocationPermission.deniedForever) {
        return Result.failure(LocationError.permissionDenied());
      }

      // If permission is denied, request it
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.denied) {
          return Result.failure(LocationError.permissionDenied());
        }

        if (permission == LocationPermission.deniedForever) {
          return Result.failure(LocationError.permissionDenied());
        }
      }

      // Permission granted
      return Result.success(true);
    } catch (e, stackTrace) {
      return Result.failure(
        LocationError(
          message: 'Failed to request location permission: $e',
          code: 'PERMISSION_REQUEST_FAILED',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Checks if location permission is granted.
  static Future<bool> hasLocationPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      return false;
    }
  }

  /// Opens the app settings page where users can enable permissions.
  ///
  /// Returns true if settings were opened successfully.
  static Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      return false;
    }
  }

  /// Opens the location settings page where users can enable GPS.
  ///
  /// Returns true if settings were opened successfully.
  static Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      return false;
    }
  }

  /// Shows a dialog explaining why location permission is needed
  /// and provides a button to open settings.
  static Future<void> showPermissionDialog(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onOpenSettings,
  }) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.location_off,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Location access is required for navigation and to show your position on the map.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              onOpenSettings();
            },
            icon: const Icon(Icons.settings),
            label: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Shows a dialog for location service disabled error.
  static Future<void> showLocationServiceDialog(BuildContext context) {
    return showPermissionDialog(
      context,
      title: 'Location Services Disabled',
      message:
          'GPS is turned off on your device. Please enable Location Services to use navigation.',
      onOpenSettings: () async {
        await openLocationSettings();
      },
    );
  }

  /// Shows a dialog for location permission denied error.
  static Future<void> showLocationPermissionDialog(BuildContext context) {
    return showPermissionDialog(
      context,
      title: 'Location Permission Required',
      message: 'This app needs access to your location to provide navigation.',
      onOpenSettings: () async {
        await openAppSettings();
      },
    );
  }

  /// Handles a location error by showing the appropriate dialog.
  ///
  /// Returns true if a dialog was shown, false otherwise.
  static Future<bool> handleLocationError(
    BuildContext context,
    LocationError error,
  ) async {
    if (error.code == 'SERVICE_DISABLED') {
      await showLocationServiceDialog(context);
      return true;
    } else if (error.code == 'PERMISSION_DENIED') {
      await showLocationPermissionDialog(context);
      return true;
    }
    return false;
  }
}
