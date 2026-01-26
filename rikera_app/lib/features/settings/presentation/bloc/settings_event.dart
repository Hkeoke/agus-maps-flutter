import 'package:rikera_app/features/settings/domain/entities/app_settings.dart';

/// Base class for settings events
abstract class SettingsEvent {
  const SettingsEvent();
}

/// Event to load settings
class LoadSettings extends SettingsEvent {
  const LoadSettings();
}

/// Event to update theme mode
class UpdateThemeMode extends SettingsEvent {
  final AppThemeMode themeMode;

  const UpdateThemeMode(this.themeMode);
}

/// Event to toggle voice guidance
class ToggleVoiceGuidance extends SettingsEvent {
  final bool enabled;

  const ToggleVoiceGuidance(this.enabled);
}

/// Event to update speed unit
class UpdateSpeedUnit extends SettingsEvent {
  final SpeedUnit speedUnit;

  const UpdateSpeedUnit(this.speedUnit);
}
