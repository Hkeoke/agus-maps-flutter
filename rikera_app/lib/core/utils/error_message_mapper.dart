import 'package:rikera_app/core/utils/result.dart';
import 'package:rikera_app/core/errors/app_errors.dart';

/// Maps technical errors to user-friendly messages with actionable guidance.
///
/// This utility provides consistent, helpful error messages across the application
/// that guide users on how to resolve issues.
///
/// Requirements: 13.1, 13.2, 13.3, 13.4
class ErrorMessageMapper {
  /// Converts an AppError to a user-friendly message.
  ///
  /// Returns a map with:
  /// - 'title': Short error title
  /// - 'message': Detailed user-friendly message
  /// - 'action': Optional actionable guidance
  /// - 'canRetry': Whether the operation can be retried
  static Map<String, dynamic> toUserMessage(AppError error) {
    if (error is NetworkError) {
      return _mapNetworkError(error);
    } else if (error is LocationError) {
      return _mapLocationError(error);
    } else if (error is RoutingError) {
      return _mapRoutingError(error);
    } else if (error is StorageError) {
      return _mapStorageError(error);
    } else if (error is MapEngineError) {
      return _mapMapEngineError(error);
    } else if (error is SearchError) {
      return _mapSearchError(error);
    } else if (error is GenericError) {
      return _mapGenericError(error);
    } else {
      return {
        'title': 'Error',
        'message': error.message,
        'action':
            'Please try again or contact support if the problem persists.',
        'canRetry': true,
      };
    }
  }

  static Map<String, dynamic> _mapNetworkError(NetworkError error) {
    switch (error.code) {
      case 'NETWORK_TIMEOUT':
        return {
          'title': 'Connection Timeout',
          'message':
              'The request took too long to complete. Please check your internet connection and try again.',
          'action': 'Retry',
          'canRetry': true,
        };
      case 'NO_CONNECTION':
        return {
          'title': 'No Internet Connection',
          'message':
              'Unable to connect to the internet. Please check your network settings.',
          'action': 'Check your Wi-Fi or mobile data connection and try again.',
          'canRetry': true,
        };
      case 'SERVER_ERROR':
        return {
          'title': 'Server Error',
          'message':
              'The server encountered an error. This is usually temporary.',
          'action': 'Please try again in a few moments.',
          'canRetry': true,
        };
      default:
        return {
          'title': 'Network Error',
          'message': error.message,
          'action': 'Check your internet connection and try again.',
          'canRetry': true,
        };
    }
  }

  static Map<String, dynamic> _mapLocationError(LocationError error) {
    switch (error.code) {
      case 'PERMISSION_DENIED':
        return {
          'title': 'Location Permission Required',
          'message':
              'This app needs access to your location to provide navigation.',
          'action':
              'Go to Settings → Apps → Rikera → Permissions and enable Location.',
          'canRetry': false,
        };
      case 'SERVICE_DISABLED':
        return {
          'title': 'Location Services Disabled',
          'message': 'GPS is turned off on your device.',
          'action': 'Enable Location Services in your device settings.',
          'canRetry': false,
        };
      case 'UNAVAILABLE':
        return {
          'title': 'Location Unavailable',
          'message':
              'Unable to determine your current location. This may be due to poor GPS signal.',
          'action': 'Try moving to an area with better sky visibility.',
          'canRetry': true,
        };
      case 'LOW_ACCURACY':
        return {
          'title': 'Low GPS Accuracy',
          'message': 'Your location accuracy is currently low.',
          'action': 'Move to an open area for better GPS signal.',
          'canRetry': true,
        };
      default:
        return {
          'title': 'Location Error',
          'message': error.message,
          'action': 'Check your location settings and try again.',
          'canRetry': true,
        };
    }
  }

  static Map<String, dynamic> _mapRoutingError(RoutingError error) {
    switch (error.code) {
      case 'NO_MAP_DATA':
        return {
          'title': 'Map Data Required',
          'message': 'No map data is available for this region.',
          'action': 'Download the required map from the Downloads screen.',
          'canRetry': false,
        };
      case 'UNREACHABLE':
        return {
          'title': 'Destination Unreachable',
          'message': 'Cannot find a driving route to this destination.',
          'action':
              'Try selecting a different destination or check if the location is accessible by car.',
          'canRetry': false,
        };
      case 'CALCULATION_TIMEOUT':
        return {
          'title': 'Route Calculation Timeout',
          'message': 'Route calculation took too long.',
          'action': 'Try again or select a closer destination.',
          'canRetry': true,
        };
      case 'CALCULATION_FAILED':
        return {
          'title': 'Route Calculation Failed',
          'message': error.message,
          'action': 'Please try again or select a different destination.',
          'canRetry': true,
        };
      default:
        return {
          'title': 'Routing Error',
          'message': error.message,
          'action': 'Please try again.',
          'canRetry': true,
        };
    }
  }

  static Map<String, dynamic> _mapStorageError(StorageError error) {
    switch (error.code) {
      case 'INSUFFICIENT_SPACE':
        return {
          'title': 'Storage Full',
          'message': 'Not enough storage space available on your device.',
          'action': 'Free up space by deleting unused maps or other files.',
          'canRetry': false,
        };
      case 'WRITE_FAILURE':
        return {
          'title': 'Save Failed',
          'message': 'Unable to save data to storage.',
          'action': 'Check your device storage and try again.',
          'canRetry': true,
        };
      case 'FILE_NOT_FOUND':
        return {
          'title': 'File Not Found',
          'message': 'The requested file could not be found.',
          'action': 'The file may have been deleted. Try downloading it again.',
          'canRetry': false,
        };
      case 'CORRUPTED_FILE':
        return {
          'title': 'Corrupted File',
          'message': 'The file is corrupted and cannot be used.',
          'action': 'Delete and re-download the file.',
          'canRetry': false,
        };
      case 'READ_FAILURE':
        return {
          'title': 'Read Failed',
          'message': 'Unable to read data from storage.',
          'action': 'Check your device storage and try again.',
          'canRetry': true,
        };
      default:
        return {
          'title': 'Storage Error',
          'message': error.message,
          'action': 'Check your device storage and try again.',
          'canRetry': true,
        };
    }
  }

  static Map<String, dynamic> _mapMapEngineError(MapEngineError error) {
    switch (error.code) {
      case 'INIT_FAILED':
        return {
          'title': 'Map Engine Error',
          'message': 'Failed to initialize the map engine.',
          'action':
              'Restart the app. If the problem persists, reinstall the app.',
          'canRetry': false,
        };
      case 'REGISTRATION_FAILED':
        return {
          'title': 'Map Registration Failed',
          'message': 'Unable to load the map file.',
          'action':
              'The map file may be corrupted. Try deleting and re-downloading it.',
          'canRetry': false,
        };
      case 'RENDERING_ERROR':
        return {
          'title': 'Map Display Error',
          'message': 'An error occurred while displaying the map.',
          'action': 'Try restarting the app.',
          'canRetry': true,
        };
      default:
        return {
          'title': 'Map Engine Error',
          'message': error.message,
          'action': 'Try restarting the app.',
          'canRetry': true,
        };
    }
  }

  static Map<String, dynamic> _mapSearchError(SearchError error) {
    switch (error.code) {
      case 'NO_RESULTS':
        return {
          'title': 'No Results Found',
          'message': 'No places match your search.',
          'action': 'Try a different search term or download more map regions.',
          'canRetry': false,
        };
      case 'INVALID_QUERY':
        return {
          'title': 'Invalid Search',
          'message': 'The search query is not valid.',
          'action': 'Please enter a valid place name or address.',
          'canRetry': false,
        };
      case 'SEARCH_FAILED':
        return {
          'title': 'Search Failed',
          'message': error.message,
          'action': 'Please try again.',
          'canRetry': true,
        };
      default:
        return {
          'title': 'Search Error',
          'message': error.message,
          'action': 'Please try again.',
          'canRetry': true,
        };
    }
  }

  static Map<String, dynamic> _mapGenericError(GenericError error) {
    switch (error.code) {
      case 'UNKNOWN':
        return {
          'title': 'Unexpected Error',
          'message': 'An unexpected error occurred.',
          'action':
              'Please try again. If the problem persists, contact support.',
          'canRetry': true,
        };
      case 'INVALID_STATE':
        return {
          'title': 'Invalid State',
          'message': error.message,
          'action': 'Please restart the app.',
          'canRetry': false,
        };
      case 'VALIDATION_ERROR':
        return {
          'title': 'Validation Error',
          'message': error.message,
          'action': 'Please check your input and try again.',
          'canRetry': false,
        };
      case 'NOT_IMPLEMENTED':
        return {
          'title': 'Feature Not Available',
          'message': 'This feature is not yet available.',
          'action': 'Check for app updates.',
          'canRetry': false,
        };
      default:
        return {
          'title': 'Error',
          'message': error.message,
          'action': 'Please try again.',
          'canRetry': true,
        };
    }
  }

  /// Gets a short user-friendly title for an error.
  static String getErrorTitle(AppError error) {
    return toUserMessage(error)['title'] as String;
  }

  /// Gets a detailed user-friendly message for an error.
  static String getErrorMessage(AppError error) {
    return toUserMessage(error)['message'] as String;
  }

  /// Gets actionable guidance for resolving an error.
  static String getErrorAction(AppError error) {
    return toUserMessage(error)['action'] as String;
  }

  /// Checks if an operation can be retried after this error.
  static bool canRetry(AppError error) {
    return toUserMessage(error)['canRetry'] as bool;
  }
}
