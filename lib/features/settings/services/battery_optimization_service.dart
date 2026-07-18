import 'package:flutter/services.dart';

/// ===============================================================
/// OpenBackup
/// File : battery_optimization_service.dart
/// Version : 1.0.0
/// Description : Native bridge for Android battery optimization readiness.
/// ===============================================================

class BatteryOptimizationService {
  BatteryOptimizationService._();

  static const MethodChannel _channel = MethodChannel(
    'openbackup/battery_optimization',
  );

  static Future<bool?> isIgnoringBatteryOptimizations() async {
    try {
      return await _channel.invokeMethod<bool>(
        'isIgnoringBatteryOptimizations',
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      return await _channel.invokeMethod<bool>(
            'requestIgnoreBatteryOptimizations',
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
