/// Application-wide constants
class AppConstants {
  AppConstants._(); // Private constructor to prevent instantiation

  // App Information
  static const String appName = 'Rikera';
  static const String appVersion = '1.0.0';

  // Map Configuration
  static const double defaultMapZoom = 15.0;
  static const double minMapZoom = 1.0;
  static const double maxMapZoom = 20.0;
  static const double defaultLatitude = 36.1408; // Gibraltar
  static const double defaultLongitude = -5.3536; // Gibraltar

  // Navigation Configuration
  static const double offRouteThresholdMeters = 50.0;
  static const double arrivalThresholdMeters = 25.0;
  static const double turnAnnouncementDistance1Meters = 500.0;
  static const double turnAnnouncementDistance2Meters = 100.0;
  static const double turnAnnouncementDistance3Meters = 50.0;

  // Location Configuration
  static const double locationUpdateIntervalSeconds = 1.0;
  static const double minLocationAccuracyMeters = 50.0;
  static const double lowLocationAccuracyMeters = 100.0;

  // Search Configuration
  static const int maxSearchResults = 20;
  static const int maxRecentSearches = 20;
  static const int searchDebounceMilliseconds = 300;

  // Storage Configuration
  static const String mapsDirectoryName = 'maps';
  static const String bookmarksKey = 'bookmarks';
  static const String preferencesKey = 'preferences';
  static const String searchHistoryKey = 'search_history';
  static const String mapViewStateKey = 'map_view_state';

  // UI Configuration
  static const double minTouchTargetSize = 48.0;
  static const double buttonBorderRadius = 8.0;
  static const double cardBorderRadius = 12.0;
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;

  // Speed Configuration
  static const double kmhToMphFactor = 0.621371;
  static const double mphToKmhFactor = 1.60934;
  static const double speedLimitWarningThreshold = 1.1; // 10% over limit

  // Download Configuration
  static const int downloadTimeoutSeconds = 300; // 5 minutes
  static const int downloadRetryAttempts = 3;
  static const int downloadRetryDelaySeconds = 5;

  // Map File Configuration
  static const String mwmFileExtension = '.mwm';
  static const List<String> bundledMapFiles = ['World.mwm', 'WorldCoasts.mwm'];

  // Routing Configuration
  static const String defaultRoutingMode = 'vehicle';
  static const int routeCalculationTimeoutSeconds = 30;

  // Voice Guidance Configuration
  static const bool defaultVoiceGuidanceEnabled = true;
  static const String defaultVoiceLanguage = 'en';

  // Theme Configuration
  static const String themePreferenceKey = 'theme_mode';
  static const String voiceGuidancePreferenceKey = 'voice_guidance_enabled';
  static const String unitsPreferenceKey = 'units_preference';

  // Error Messages
  static const String genericErrorMessage =
      'An unexpected error occurred. Please try again.';
  static const String networkErrorMessage =
      'Network error. Please check your connection and try again.';
  static const String locationErrorMessage =
      'Unable to access location. Please check permissions.';
  static const String mapDownloadErrorMessage =
      'Failed to download map. Please try again.';
  static const String routeCalculationErrorMessage =
      'Failed to calculate route. Please try again.';

  // Validation
  static const int minBookmarkNameLength = 1;
  static const int maxBookmarkNameLength = 100;
  static const int minSearchQueryLength = 2;
}

/// Routing modes
enum RoutingMode {
  vehicle,
  pedestrian,
  bicycle;

  String get value => name;
}

/// Theme modes
enum ThemeMode {
  light,
  dark,
  system;

  String get value => name;
}

/// Speed units
enum SpeedUnit {
  kmh('km/h'),
  mph('mph');

  const SpeedUnit(this.displayName);
  final String displayName;

  String get value => name;
}

/// Turn directions
enum TurnDirection {
  straight,
  slightRight,
  right,
  sharpRight,
  uTurnRight,
  uTurnLeft,
  sharpLeft,
  left,
  slightLeft,
  reachedDestination;

  String get displayName {
    switch (this) {
      case TurnDirection.straight:
        return 'Continue straight';
      case TurnDirection.slightRight:
        return 'Slight right';
      case TurnDirection.right:
        return 'Turn right';
      case TurnDirection.sharpRight:
        return 'Sharp right';
      case TurnDirection.uTurnRight:
        return 'U-turn right';
      case TurnDirection.uTurnLeft:
        return 'U-turn left';
      case TurnDirection.sharpLeft:
        return 'Sharp left';
      case TurnDirection.left:
        return 'Turn left';
      case TurnDirection.slightLeft:
        return 'Slight left';
      case TurnDirection.reachedDestination:
        return 'You have arrived';
    }
  }
}

/// Search result types
enum SearchResultType {
  address,
  poi,
  city,
  street,
  building,
  other;

  String get displayName {
    switch (this) {
      case SearchResultType.address:
        return 'Address';
      case SearchResultType.poi:
        return 'Point of Interest';
      case SearchResultType.city:
        return 'City';
      case SearchResultType.street:
        return 'Street';
      case SearchResultType.building:
        return 'Building';
      case SearchResultType.other:
        return 'Location';
    }
  }
}
