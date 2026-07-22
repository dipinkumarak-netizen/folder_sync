import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/openbackup_database.dart';
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
      final database = await OpenBackupDatabase.instance.database;
      final storedSettings = await _loadFromDatabase(database);
      if (storedSettings != null) {
        _settings = storedSettings;
        return;
      }

      final legacySettings = await _loadFromJson();
      if (legacySettings == null) {
        return;
      }

      _settings = legacySettings;
      await _saveToDatabase(database);
    } catch (_) {
      _settings = await _loadFromJson() ?? _settings;
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
      final database = await OpenBackupDatabase.instance.database;
      await _saveToDatabase(database);
      return;
    } catch (_) {
      await _saveToJson();
    }
  }

  Future<AppSettingsModel?> _loadFromDatabase(Database database) async {
    final rows = await database.query(
      OpenBackupDatabase.appSettingsTable,
      where: 'id = ?',
      whereArgs: const [1],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }

    return _settingsFromRow(rows.first);
  }

  Future<void> _saveToDatabase(Database database) async {
    await database.insert(
      OpenBackupDatabase.appSettingsTable,
      _settingsToRow(_settings),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<AppSettingsModel?> _loadFromJson() async {
    try {
      final file = await _storageFile().timeout(const Duration(seconds: 1));
      if (!await file.exists()) {
        return null;
      }

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      return AppSettingsModel.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveToJson() async {
    try {
      final file = await _storageFile();
      await file.writeAsString(jsonEncode(_settings.toJson()));
    } catch (_) {
      return;
    }
  }

  Map<String, Object?> _settingsToRow(AppSettingsModel settings) {
    return {
      'id': 1,
      'automatic_scheduling_enabled': settings.automaticSchedulingEnabled
          ? 1
          : 0,
      'default_backup_wifi_only': settings.defaultBackupWifiOnly ? 1 : 0,
      'default_sync_wifi_only': settings.defaultSyncWifiOnly ? 1 : 0,
      'show_foreground_notifications': settings.showForegroundNotifications
          ? 1
          : 0,
      'onboarding_completed': settings.onboardingCompleted ? 1 : 0,
      'biometric_lock_enabled': settings.biometricLockEnabled ? 1 : 0,
    };
  }

  AppSettingsModel _settingsFromRow(Map<String, Object?> row) {
    return AppSettingsModel(
      automaticSchedulingEnabled: _boolFromInt(
        row['automatic_scheduling_enabled'],
        fallback: true,
      ),
      defaultBackupWifiOnly: _boolFromInt(
        row['default_backup_wifi_only'],
        fallback: true,
      ),
      defaultSyncWifiOnly: _boolFromInt(
        row['default_sync_wifi_only'],
        fallback: true,
      ),
      showForegroundNotifications: _boolFromInt(
        row['show_foreground_notifications'],
        fallback: true,
      ),
      onboardingCompleted: _boolFromInt(row['onboarding_completed']),
      biometricLockEnabled: _boolFromInt(row['biometric_lock_enabled']),
    );
  }

  bool _boolFromInt(Object? value, {bool fallback = false}) {
    if (value is int) {
      return value == 1;
    }

    return fallback;
  }
}
