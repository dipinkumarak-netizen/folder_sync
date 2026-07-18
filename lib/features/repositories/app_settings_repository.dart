import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../settings/models/app_settings_model.dart';

/// ===============================================================
/// OpenBackup
/// File : app_settings_repository.dart
/// Version : 1.0.0
/// Description : Persistent repository for application settings.
/// ===============================================================

class AppSettingsRepository {
  AppSettingsRepository._();

  static final AppSettingsRepository instance = AppSettingsRepository._();

  AppSettingsModel _settings = const AppSettingsModel();
  bool _loaded = false;

  AppSettingsModel get() {
    return _settings;
  }

  Future<void> load() async {
    if (_loaded) {
      return;
    }

    _loaded = true;

    try {
      final file = await _storageFile().timeout(const Duration(seconds: 1));
      if (!await file.exists()) {
        return;
      }

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      _settings = AppSettingsModel.fromJson(decoded);
    } catch (_) {
      return;
    }
  }

  void update(AppSettingsModel settings) {
    _settings = settings;
    unawaited(_save());
  }

  Future<File> _storageFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final storageDirectory = Directory('${directory.path}/openbackup');
    if (!await storageDirectory.exists()) {
      await storageDirectory.create(recursive: true);
    }

    return File('${storageDirectory.path}/app_settings.json');
  }

  Future<void> _save() async {
    try {
      final file = await _storageFile();
      await file.writeAsString(jsonEncode(_settings.toJson()));
    } catch (_) {
      return;
    }
  }
}
