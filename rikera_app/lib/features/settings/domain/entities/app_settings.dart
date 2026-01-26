/// Application settings entity
class AppSettings {
  final AppThemeMode themeMode;
  final bool voiceGuidanceEnabled;
  final SpeedUnit speedUnit;

  const AppSettings({
    required this.themeMode,
    required this.voiceGuidanceEnabled,
    required this.speedUnit,
  });

  /// Default settings
  factory AppSettings.defaults() {
    return const AppSettings(
      themeMode: AppThemeMode.system,
      voiceGuidanceEnabled: true,
      speedUnit: SpeedUnit.metric,
    );
  }

  AppSettings copyWith({
    AppThemeMode? themeMode,
    bool? voiceGuidanceEnabled,
    SpeedUnit? speedUnit,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      voiceGuidanceEnabled: voiceGuidanceEnabled ?? this.voiceGuidanceEnabled,
      speedUnit: speedUnit ?? this.speedUnit,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSettings &&
        other.themeMode == themeMode &&
        other.voiceGuidanceEnabled == voiceGuidanceEnabled &&
        other.speedUnit == speedUnit;
  }

  @override
  int get hashCode =>
      themeMode.hashCode ^ voiceGuidanceEnabled.hashCode ^ speedUnit.hashCode;
}

/// Theme mode options
enum AppThemeMode { light, dark, system }

/// Speed unit options
enum SpeedUnit {
  metric, // km/h
  imperial, // mph
}

extension SpeedUnitExtension on SpeedUnit {
  String get label {
    switch (this) {
      case SpeedUnit.metric:
        return 'km/h';
      case SpeedUnit.imperial:
        return 'mph';
    }
  }

  /// Convert speed from m/s to the appropriate unit
  double convertFromMetersPerSecond(double speedMs) {
    switch (this) {
      case SpeedUnit.metric:
        return speedMs * 3.6; // m/s to km/h
      case SpeedUnit.imperial:
        return speedMs * 2.23694; // m/s to mph
    }
  }
}

extension AppThemeModeExtension on AppThemeMode {
  String get label {
    switch (this) {
      case AppThemeMode.light:
        return 'Day';
      case AppThemeMode.dark:
        return 'Night';
      case AppThemeMode.system:
        return 'Auto';
    }
  }
}
