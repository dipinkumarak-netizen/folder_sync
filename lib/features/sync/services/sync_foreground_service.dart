import 'package:flutter/services.dart';

/// ===============================================================
/// OpenBackup
/// File : sync_foreground_service.dart
/// Version : 1.0.0
/// Description : Flutter bridge for native sync foreground progress.
/// ===============================================================

class SyncForegroundServiceBridge {
  SyncForegroundServiceBridge._();

  static const MethodChannel _channel = MethodChannel(
    'openbackup/backup_foreground_service',
  );

  static Future<bool> start({required String message}) async {
    try {
      final started = await _channel.invokeMethod<bool>('start', {
        'title': 'OpenBackup Sync',
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
}
