import 'package:rikera_app/features/settings/domain/entities/app_settings.dart';

/// Base class for settings states
abstract class SettingsState {
  const SettingsState();
}

/// Initial state
class SettingsInitial extends SettingsState {
  const SettingsInitial();
}

/// Loading state
class SettingsLoading extends SettingsState {
  const SettingsLoading();
}

/// Loaded state with settings
class SettingsLoaded extends SettingsState {
  final AppSettings settings;

  const SettingsLoaded(this.settings);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SettingsLoaded && other.settings == settings;
  }

  @override
  int get hashCode => settings.hashCode;
}

/// Error state
class SettingsError extends SettingsState {
  final String message;

  const SettingsError(this.message);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SettingsError && other.message == message;
  }

  @override
  int get hashCode => message.hashCode;
}
