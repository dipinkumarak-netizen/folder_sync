import 'dart:io';

import 'package:flutter/services.dart';

/// ===============================================================
/// OpenBackup
/// File : android_instant_sync_service.dart
/// Version : 1.0.0
/// Description : Flutter bridge for Android instant sync file watchers.
/// ===============================================================

class AndroidInstantSyncService {
  AndroidInstantSyncService._();

  static const MethodChannel _channel = MethodChannel(
    'openbackup/instant_sync',
  );

  static Future<bool> configure({
    required bool enabled,
    required List<String> localFolderPaths,
  }) async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final configured = await _channel.invokeMethod<bool>('configure', {
        'enabled': enabled,
        'paths': localFolderPaths,
      });
      return configured ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> cancel() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('cancel');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}
