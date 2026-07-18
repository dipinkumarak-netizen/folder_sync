import 'package:flutter/services.dart';

/// ===============================================================
/// OpenBackup
/// File : android_background_scheduler_service.dart
/// Version : 1.0.0
/// Description : Flutter bridge for Android background schedule alarms.
/// ===============================================================

class AndroidBackgroundSchedulerService {
  AndroidBackgroundSchedulerService._();

  static const MethodChannel _channel = MethodChannel(
    'openbackup/background_scheduler',
  );

  static Future<bool> configure({
    required bool enabled,
    required int intervalMinutes,
  }) async {
    try {
      final configured = await _channel.invokeMethod<bool>('configure', {
        'enabled': enabled,
        'intervalMinutes': intervalMinutes,
      });
      return configured ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}
