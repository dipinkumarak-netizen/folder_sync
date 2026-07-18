import 'package:flutter/services.dart';

/// ===============================================================
/// OpenBackup
/// File : wifi_status_service.dart
/// Version : 1.0.0
/// Description : Native bridge for current Wi-Fi status.
/// ===============================================================

class WifiStatusService {
  WifiStatusService._();

  static const MethodChannel _channel = MethodChannel('openbackup/wifi_status');

  static Future<String?> currentSsid() async {
    try {
      final ssid = await _channel.invokeMethod<String>('currentSsid');
      final trimmed = ssid?.trim();
      if (trimmed == null || trimmed.isEmpty) {
        return null;
      }

      return trimmed;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
