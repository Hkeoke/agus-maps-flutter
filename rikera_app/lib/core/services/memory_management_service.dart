import 'package:rikera_app/core/utils/logger.dart';

/// Service for managing memory usage across the application.
///
/// This service provides methods to release resources when they are not needed,
/// helping to maintain stable memory usage during long sessions.
///
/// Requirements: 11.1, 11.2, 11.3
class MemoryManagementService {
  final AppLogger _logger = const AppLogger('MemoryManagement');

  /// List of callbacks to invoke when memory should be released.
  final List<void Function()> _releaseCallbacks = [];

  /// Registers a callback to be invoked when memory should be released.
  ///
  /// This allows different parts of the app to register cleanup functions
  /// that will be called when memory pressure is detected or when the app
  /// is backgrounded.
  void registerReleaseCallback(void Function() callback) {
    _releaseCallbacks.add(callback);
    _logger.debug('Registered memory release callback');
  }

  /// Unregisters a previously registered callback.
  void unregisterReleaseCallback(void Function() callback) {
    _releaseCallbacks.remove(callback);
    _logger.debug('Unregistered memory release callback');
  }

  /// Releases non-essential resources to free memory.
  ///
  /// This should be called when:
  /// - The app is backgrounded
  /// - Memory pressure is detected
  /// - The user navigates away from a memory-intensive screen
  ///
  /// This method invokes all registered release callbacks.
  void releaseResources() {
    _logger.info('Releasing non-essential resources');

    for (final callback in _releaseCallbacks) {
      try {
        callback();
      } catch (e, stackTrace) {
        _logger.error(
          'Error in release callback',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }

    _logger.info('Released ${_releaseCallbacks.length} resource(s)');
  }

  /// Clears all registered callbacks.
  ///
  /// This should be called when the service is disposed.
  void dispose() {
    _releaseCallbacks.clear();
    _logger.debug('Memory management service disposed');
  }
}
