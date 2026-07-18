import 'package:flutter/services.dart';

/// ===============================================================
/// OpenBackup
/// File : restore_foreground_service.dart
/// Version : 1.0.0
/// Description : Flutter bridge for native restore foreground progress.
/// ===============================================================

class RestoreForegroundServiceBridge {
  RestoreForegroundServiceBridge._();

  static const MethodChannel _channel = MethodChannel(
    'openbackup/backup_foreground_service',
  );

  static Future<bool> start({String message = 'Restore is running'}) async {
    try {
      final started = await _channel.invokeMethod<bool>('start', {
        'title': 'OpenBackup Restore',
        'message': message,
      });
      return started ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> update({required String message}) async {
    await start(message: message);
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}
