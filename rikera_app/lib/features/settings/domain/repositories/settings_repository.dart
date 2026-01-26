import 'package:rikera_app/core/utils/result.dart';
import 'package:rikera_app/features/settings/domain/entities/app_settings.dart';

/// Repository interface for managing application settings
abstract class SettingsRepository {
  /// Get current settings
  Future<Result<AppSettings>> getSettings();

  /// Save settings
  Future<Result<void>> saveSettings(AppSettings settings);

  /// Update theme mode
  Future<Result<void>> updateThemeMode(AppThemeMode themeMode);

  /// Update voice guidance enabled state
  Future<Result<void>> updateVoiceGuidance(bool enabled);

  /// Update speed unit
  Future<Result<void>> updateSpeedUnit(SpeedUnit speedUnit);
}
