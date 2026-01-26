import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rikera_app/features/settings/domain/entities/app_settings.dart';
import 'package:rikera_app/features/settings/domain/usecases/get_settings_usecase.dart';
import 'package:rikera_app/features/settings/domain/usecases/update_settings_usecase.dart';
import 'package:rikera_app/features/settings/presentation/bloc/settings_event.dart';
import 'package:rikera_app/features/settings/presentation/bloc/settings_state.dart';

/// Bloc for managing application settings
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final GetSettingsUseCase _getSettingsUseCase;
  final UpdateSettingsUseCase _updateSettingsUseCase;

  AppSettings? _currentSettings;

  SettingsBloc({
    required GetSettingsUseCase getSettingsUseCase,
    required UpdateSettingsUseCase updateSettingsUseCase,
  }) : _getSettingsUseCase = getSettingsUseCase,
       _updateSettingsUseCase = updateSettingsUseCase,
       super(const SettingsInitial()) {
    on<LoadSettings>(_onLoadSettings);
    on<UpdateThemeMode>(_onUpdateThemeMode);
    on<ToggleVoiceGuidance>(_onToggleVoiceGuidance);
    on<UpdateSpeedUnit>(_onUpdateSpeedUnit);
  }

  Future<void> _onLoadSettings(
    LoadSettings event,
    Emitter<SettingsState> emit,
  ) async {
    emit(const SettingsLoading());

    final result = await _getSettingsUseCase.execute();

    result.fold(
      onSuccess: (settings) {
        _currentSettings = settings;
        emit(SettingsLoaded(settings));
      },
      onFailure: (error) {
        // If loading fails, use defaults
        _currentSettings = AppSettings.defaults();
        emit(SettingsLoaded(_currentSettings!));
      },
    );
  }

  Future<void> _onUpdateThemeMode(
    UpdateThemeMode event,
    Emitter<SettingsState> emit,
  ) async {
    if (_currentSettings == null) return;

    final updatedSettings = _currentSettings!.copyWith(
      themeMode: event.themeMode,
    );

    final result = await _updateSettingsUseCase.execute(updatedSettings);

    result.fold(
      onSuccess: (_) {
        _currentSettings = updatedSettings;
        emit(SettingsLoaded(updatedSettings));
      },
      onFailure: (error) {
        emit(SettingsError(error.message));
        // Restore previous state
        if (_currentSettings != null) {
          emit(SettingsLoaded(_currentSettings!));
        }
      },
    );
  }

  Future<void> _onToggleVoiceGuidance(
    ToggleVoiceGuidance event,
    Emitter<SettingsState> emit,
  ) async {
    if (_currentSettings == null) return;

    final updatedSettings = _currentSettings!.copyWith(
      voiceGuidanceEnabled: event.enabled,
    );

    final result = await _updateSettingsUseCase.execute(updatedSettings);

    result.fold(
      onSuccess: (_) {
        _currentSettings = updatedSettings;
        emit(SettingsLoaded(updatedSettings));
      },
      onFailure: (error) {
        emit(SettingsError(error.message));
        // Restore previous state
        if (_currentSettings != null) {
          emit(SettingsLoaded(_currentSettings!));
        }
      },
    );
  }

  Future<void> _onUpdateSpeedUnit(
    UpdateSpeedUnit event,
    Emitter<SettingsState> emit,
  ) async {
    if (_currentSettings == null) return;

    final updatedSettings = _currentSettings!.copyWith(
      speedUnit: event.speedUnit,
    );

    final result = await _updateSettingsUseCase.execute(updatedSettings);

    result.fold(
      onSuccess: (_) {
        _currentSettings = updatedSettings;
        emit(SettingsLoaded(updatedSettings));
      },
      onFailure: (error) {
        emit(SettingsError(error.message));
        // Restore previous state
        if (_currentSettings != null) {
          emit(SettingsLoaded(_currentSettings!));
        }
      },
    );
  }
}
