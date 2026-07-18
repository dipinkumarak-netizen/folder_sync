import 'package:flutter/services.dart';

/// ===============================================================
/// OpenBackup
/// File : headless_scheduler_bridge.dart
/// Version : 1.0.0
/// Description : Flutter bridge for native headless scheduler lifecycle.
/// ===============================================================

class HeadlessSchedulerBridge {
  HeadlessSchedulerBridge._();

  static const MethodChannel _channel = MethodChannel(
    'openbackup/headless_scheduler',
  );

  static Future<void> complete({required String message}) async {
    try {
      await _channel.invokeMethod<void>('complete', {'message': message});
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}
