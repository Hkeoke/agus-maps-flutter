import 'package:rikera_app/core/utils/result.dart';
import 'package:rikera_app/features/settings/domain/entities/app_settings.dart';
import 'package:rikera_app/features/settings/domain/repositories/settings_repository.dart';

/// Use case for getting application settings
class GetSettingsUseCase {
  final SettingsRepository _repository;

  GetSettingsUseCase(this._repository);

  Future<Result<AppSettings>> execute() async {
    return await _repository.getSettings();
  }
}
