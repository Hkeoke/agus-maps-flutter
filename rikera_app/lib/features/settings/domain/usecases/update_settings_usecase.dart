import 'package:rikera_app/core/utils/result.dart';
import 'package:rikera_app/features/settings/domain/entities/app_settings.dart';
import 'package:rikera_app/features/settings/domain/repositories/settings_repository.dart';

/// Use case for updating application settings
class UpdateSettingsUseCase {
  final SettingsRepository _repository;

  UpdateSettingsUseCase(this._repository);

  Future<Result<void>> execute(AppSettings settings) async {
    return await _repository.saveSettings(settings);
  }
}
