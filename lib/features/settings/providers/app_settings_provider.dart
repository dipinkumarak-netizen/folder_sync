import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/app_settings_repository.dart';
import '../models/app_settings_model.dart';

/// ===============================================================
/// OpenBackup
/// File : app_settings_provider.dart
/// Version : 1.0.0
/// Description : Riverpod provider for application settings.
/// ===============================================================

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  return AppSettingsRepository.instance;
});

class AppSettingsNotifier extends StateNotifier<AppSettingsModel> {
  AppSettingsNotifier(this._repository) : super(_repository.get());

  final AppSettingsRepository _repository;

  Future<void> loadSettings() async {
    await _repository.load();
    state = _repository.get();
  }

  Future<void> updateSettings(AppSettingsModel settings) async {
    _repository.update(settings);
    state = settings;
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettingsModel>((ref) {
      final repository = ref.watch(appSettingsRepositoryProvider);
      return AppSettingsNotifier(repository);
    });

final appSettingsLoadProvider = FutureProvider<void>((ref) async {
  await ref.read(appSettingsProvider.notifier).loadSettings();
});
