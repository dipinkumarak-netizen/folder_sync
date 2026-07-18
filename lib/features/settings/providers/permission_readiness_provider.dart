import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/battery_optimization_service.dart';

/// ===============================================================
/// OpenBackup
/// File : permission_readiness_provider.dart
/// Version : 1.0.0
/// Description : Runtime storage and permission readiness checks.
/// ===============================================================

enum ReadinessStatus { ready, warning, blocked, unknown }

class PermissionReadinessItem {
  final String id;
  final String title;
  final String message;
  final ReadinessStatus status;
  final String actionLabel;

  const PermissionReadinessItem({
    required this.id,
    required this.title,
    required this.message,
    required this.status,
    required this.actionLabel,
  });
}

class PermissionReadinessSnapshot {
  final List<PermissionReadinessItem> items;

  const PermissionReadinessSnapshot({required this.items});

  int get readyCount =>
      items.where((item) => item.status == ReadinessStatus.ready).length;

  int get issueCount => items.length - readyCount;

  bool get allReady => issueCount == 0;
}

class PermissionReadinessNotifier
    extends StateNotifier<AsyncValue<PermissionReadinessSnapshot>> {
  PermissionReadinessNotifier() : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_readSnapshot);
  }

  Future<void> requestNotification() async {
    await Permission.notification.request();
    await refresh();
  }

  Future<void> requestWifiNameAccess() async {
    await Permission.nearbyWifiDevices.request();
    await Permission.locationWhenInUse.request();
    await refresh();
  }

  Future<void> requestBatteryOptimizationExemption() async {
    await BatteryOptimizationService.requestIgnoreBatteryOptimizations();
    await refresh();
  }

  Future<PermissionReadinessSnapshot> _readSnapshot() async {
    final notification = await Permission.notification.status;
    final nearbyWifi = await Permission.nearbyWifiDevices.status;
    final location = await Permission.locationWhenInUse.status;
    final batteryOptimizationIgnored =
        await BatteryOptimizationService.isIgnoringBatteryOptimizations();
    final storageWritable = await _canWriteAppStorage();

    return PermissionReadinessSnapshot(
      items: [
        PermissionReadinessItem(
          id: 'app_storage',
          title: 'App Storage',
          message: storageWritable
              ? 'Local app storage is writable.'
              : 'OpenBackup cannot write to local app storage.',
          status: storageWritable
              ? ReadinessStatus.ready
              : ReadinessStatus.blocked,
          actionLabel: 'Refresh',
        ),
        PermissionReadinessItem(
          id: 'folder_picker',
          title: 'Folder Access',
          message:
              'Backup, sync, and restore folders are granted when you select each folder.',
          status: ReadinessStatus.ready,
          actionLabel: 'Open Settings',
        ),
        PermissionReadinessItem(
          id: 'notifications',
          title: 'Foreground Notifications',
          message: notification.isGranted
              ? 'Progress notifications can be shown.'
              : 'Android may hide long-running backup progress.',
          status: notification.isGranted
              ? ReadinessStatus.ready
              : notification.isPermanentlyDenied
              ? ReadinessStatus.blocked
              : ReadinessStatus.warning,
          actionLabel: notification.isPermanentlyDenied ? 'Settings' : 'Allow',
        ),
        PermissionReadinessItem(
          id: 'wifi_name',
          title: 'Wi-Fi Name Access',
          message: nearbyWifi.isGranted || location.isGranted
              ? 'Home Wi-Fi rules can check the current network.'
              : 'Home Wi-Fi rules may be skipped until permission is allowed.',
          status: nearbyWifi.isGranted || location.isGranted
              ? ReadinessStatus.ready
              : nearbyWifi.isPermanentlyDenied || location.isPermanentlyDenied
              ? ReadinessStatus.blocked
              : ReadinessStatus.warning,
          actionLabel:
              nearbyWifi.isPermanentlyDenied || location.isPermanentlyDenied
              ? 'Settings'
              : 'Allow',
        ),
        PermissionReadinessItem(
          id: 'battery',
          title: 'Battery Optimization',
          message: batteryOptimizationIgnored == true
              ? 'Android is less likely to interrupt scheduled work.'
              : batteryOptimizationIgnored == false
              ? 'Scheduled jobs may be delayed by battery optimization.'
              : 'Battery optimization status is unavailable on this device.',
          status: batteryOptimizationIgnored == true
              ? ReadinessStatus.ready
              : batteryOptimizationIgnored == false
              ? ReadinessStatus.warning
              : ReadinessStatus.unknown,
          actionLabel: batteryOptimizationIgnored == null ? 'Refresh' : 'Allow',
        ),
      ],
    );
  }

  Future<bool> _canWriteAppStorage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final testFile = File('${directory.path}/openbackup/readiness_check.tmp');
      await testFile.parent.create(recursive: true);
      await testFile.writeAsString('ok');
      await testFile.delete();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final permissionReadinessProvider =
    StateNotifierProvider<
      PermissionReadinessNotifier,
      AsyncValue<PermissionReadinessSnapshot>
    >((ref) {
      return PermissionReadinessNotifier();
    });
