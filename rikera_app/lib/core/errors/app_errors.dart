import '../utils/result.dart';

/// Network-related errors (map downloads, region list fetching)
class NetworkError extends AppError {
  const NetworkError({required super.message, super.code, super.stackTrace});

  factory NetworkError.timeout() => const NetworkError(
    message: 'Network request timed out',
    code: 'NETWORK_TIMEOUT',
  );

  factory NetworkError.noConnection() => const NetworkError(
    message: 'No internet connection available',
    code: 'NO_CONNECTION',
  );

  factory NetworkError.serverError() => const NetworkError(
    message: 'Server error occurred',
    code: 'SERVER_ERROR',
  );

  factory NetworkError.unknown(String message) =>
      NetworkError(message: message, code: 'NETWORK_UNKNOWN');
}

/// Location service errors (GPS, permissions)
class LocationError extends AppError {
  const LocationError({required super.message, super.code, super.stackTrace});

  factory LocationError.permissionDenied() => const LocationError(
    message:
        'Location permission denied. Please enable location access in settings.',
    code: 'PERMISSION_DENIED',
  );

  factory LocationError.serviceDisabled() => const LocationError(
    message: 'Location services are disabled. Please enable GPS in settings.',
    code: 'SERVICE_DISABLED',
  );

  factory LocationError.unavailable() => const LocationError(
    message: 'Location is currently unavailable',
    code: 'UNAVAILABLE',
  );

  factory LocationError.lowAccuracy() => const LocationError(
    message: 'Location accuracy is too low',
    code: 'LOW_ACCURACY',
  );
}

/// Routing and navigation errors
class RoutingError extends AppError {
  const RoutingError({required super.message, super.code, super.stackTrace});

  factory RoutingError.noMapData() => const RoutingError(
    message:
        'No map data available for this region. Please download the required map.',
    code: 'NO_MAP_DATA',
  );

  factory RoutingError.destinationUnreachable() => const RoutingError(
    message: 'Destination is unreachable by car',
    code: 'UNREACHABLE',
  );

  factory RoutingError.calculationTimeout() => const RoutingError(
    message: 'Route calculation timed out',
    code: 'CALCULATION_TIMEOUT',
  );

  factory RoutingError.calculationFailed(String reason) => RoutingError(
    message: 'Route calculation failed: $reason',
    code: 'CALCULATION_FAILED',
  );
}

/// Storage and file system errors
class StorageError extends AppError {
  const StorageError({required super.message, super.code, super.stackTrace});

  factory StorageError.insufficientSpace() => const StorageError(
    message: 'Insufficient storage space available',
    code: 'INSUFFICIENT_SPACE',
  );

  factory StorageError.writeFailure() => const StorageError(
    message: 'Failed to write to storage',
    code: 'WRITE_FAILURE',
  );

  factory StorageError.fileNotFound(String fileName) => StorageError(
    message: 'File not found: $fileName',
    code: 'FILE_NOT_FOUND',
  );

  factory StorageError.corruptedFile(String fileName) => StorageError(
    message: 'File is corrupted: $fileName',
    code: 'CORRUPTED_FILE',
  );

  factory StorageError.readFailure() => const StorageError(
    message: 'Failed to read from storage',
    code: 'READ_FAILURE',
  );
}

/// Map engine errors (CoMaps initialization, rendering)
class MapEngineError extends AppError {
  const MapEngineError({required super.message, super.code, super.stackTrace});

  factory MapEngineError.initializationFailed() => const MapEngineError(
    message: 'Failed to initialize map engine',
    code: 'INIT_FAILED',
  );

  factory MapEngineError.registrationFailed(String fileName) => MapEngineError(
    message: 'Failed to register map file: $fileName',
    code: 'REGISTRATION_FAILED',
  );

  factory MapEngineError.renderingError() => const MapEngineError(
    message: 'Map rendering error occurred',
    code: 'RENDERING_ERROR',
  );
}

/// Search-related errors
class SearchError extends AppError {
  const SearchError({required super.message, super.code, super.stackTrace});

  factory SearchError.noResults() => const SearchError(
    message: 'No results found for your search',
    code: 'NO_RESULTS',
  );

  factory SearchError.invalidQuery() =>
      const SearchError(message: 'Invalid search query', code: 'INVALID_QUERY');

  factory SearchError.searchFailed(String reason) =>
      SearchError(message: 'Search failed: $reason', code: 'SEARCH_FAILED');
}

/// Generic application errors
class GenericError extends AppError {
  const GenericError({required super.message, super.code, super.stackTrace});

  factory GenericError.unknown(String message, [StackTrace? stackTrace]) =>
      GenericError(message: message, code: 'UNKNOWN', stackTrace: stackTrace);

  factory GenericError.invalidState(String message) =>
      GenericError(message: message, code: 'INVALID_STATE');

  factory GenericError.validation(String message) =>
      GenericError(message: message, code: 'VALIDATION_ERROR');

  factory GenericError.notImplemented() => const GenericError(
    message: 'Feature not yet implemented',
    code: 'NOT_IMPLEMENTED',
  );
}
