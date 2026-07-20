import 'package:flutter/services.dart';

/// ===============================================================
/// OpenBackup
/// File : backup_foreground_service.dart
/// Version : 1.0.0
/// Description : Flutter bridge for the native data-sync foreground service.
/// ===============================================================

class BackupForegroundServiceBridge {
  BackupForegroundServiceBridge._();

  static const MethodChannel _channel = MethodChannel(
    'openbackup/backup_foreground_service',
  );

  static Future<bool> start({
    String title = 'OpenBackup',
    String message = 'Backup is running',
  }) async {
    try {
      final started = await _channel.invokeMethod<bool>('start', {
        'title': title,
        'message': message,
      });
      return started ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
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

  static Future<void> update({
    String title = 'OpenBackup',
    required String message,
  }) async {
    await start(title: title, message: message);
  }
}
