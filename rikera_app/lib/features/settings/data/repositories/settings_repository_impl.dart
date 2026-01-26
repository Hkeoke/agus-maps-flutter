import 'package:rikera_app/core/utils/result.dart';
import 'package:rikera_app/core/errors/app_errors.dart';
import 'package:rikera_app/features/settings/data/datasources/settings_data_source.dart';
import 'package:rikera_app/features/settings/domain/entities/app_settings.dart';
import 'package:rikera_app/features/settings/domain/repositories/settings_repository.dart';

/// Implementation of SettingsRepository
class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsDataSource _dataSource;

  SettingsRepositoryImpl({required SettingsDataSource dataSource})
    : _dataSource = dataSource;

  @override
  Future<Result<AppSettings>> getSettings() async {
    try {
      final settings = await _dataSource.loadSettings();
      return Result.success(settings);
    } catch (e, stackTrace) {
      return Result.failure(
        GenericError.unknown('Failed to load settings: $e', stackTrace),
      );
    }
  }

  @override
  Future<Result<void>> saveSettings(AppSettings settings) async {
    try {
      await _dataSource.saveSettings(settings);
      return Result.success(null);
    } catch (e, stackTrace) {
      return Result.failure(
        GenericError.unknown('Failed to save settings: $e', stackTrace),
      );
    }
  }

  @override
  Future<Result<void>> updateThemeMode(AppThemeMode themeMode) async {
    try {
      await _dataSource.updateThemeMode(themeMode);
      return Result.success(null);
    } catch (e, stackTrace) {
      return Result.failure(
        GenericError.unknown('Failed to update theme mode: $e', stackTrace),
      );
    }
  }

  @override
  Future<Result<void>> updateVoiceGuidance(bool enabled) async {
    try {
      await _dataSource.updateVoiceGuidance(enabled);
      return Result.success(null);
    } catch (e, stackTrace) {
      return Result.failure(
        GenericError.unknown('Failed to update voice guidance: $e', stackTrace),
      );
    }
  }

  @override
  Future<Result<void>> updateSpeedUnit(SpeedUnit speedUnit) async {
    try {
      await _dataSource.updateSpeedUnit(speedUnit);
      return Result.success(null);
    } catch (e, stackTrace) {
      return Result.failure(
        GenericError.unknown('Failed to update speed unit: $e', stackTrace),
      );
    }
  }
}
