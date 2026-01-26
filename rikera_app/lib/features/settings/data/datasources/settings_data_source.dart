import 'package:shared_preferences/shared_preferences.dart';
import 'package:rikera_app/features/settings/domain/entities/app_settings.dart';

/// Data source for persisting settings using SharedPreferences
class SettingsDataSource {
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyVoiceGuidance = 'voice_guidance_enabled';
  static const String _keySpeedUnit = 'speed_unit';

  final SharedPreferences _prefs;

  SettingsDataSource._(this._prefs);

  /// Create and initialize the settings data source
  static Future<SettingsDataSource> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsDataSource._(prefs);
  }

  /// Load settings from storage
  Future<AppSettings> loadSettings() async {
    final themeModeIndex = _prefs.getInt(_keyThemeMode);
    final voiceEnabled = _prefs.getBool(_keyVoiceGuidance);
    final speedUnitIndex = _prefs.getInt(_keySpeedUnit);

    return AppSettings(
      themeMode: themeModeIndex != null
          ? AppThemeMode.values[themeModeIndex]
          : AppThemeMode.system,
      voiceGuidanceEnabled: voiceEnabled ?? true,
      speedUnit: speedUnitIndex != null
          ? SpeedUnit.values[speedUnitIndex]
          : SpeedUnit.metric,
    );
  }

  /// Save settings to storage
  Future<void> saveSettings(AppSettings settings) async {
    await Future.wait([
      _prefs.setInt(_keyThemeMode, settings.themeMode.index),
      _prefs.setBool(_keyVoiceGuidance, settings.voiceGuidanceEnabled),
      _prefs.setInt(_keySpeedUnit, settings.speedUnit.index),
    ]);
  }

  /// Update theme mode
  Future<void> updateThemeMode(AppThemeMode themeMode) async {
    await _prefs.setInt(_keyThemeMode, themeMode.index);
  }

  /// Update voice guidance
  Future<void> updateVoiceGuidance(bool enabled) async {
    await _prefs.setBool(_keyVoiceGuidance, enabled);
  }

  /// Update speed unit
  Future<void> updateSpeedUnit(SpeedUnit speedUnit) async {
    await _prefs.setInt(_keySpeedUnit, speedUnit.index);
  }
}
