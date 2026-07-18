import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../backup/providers/backup_provider.dart';
import '../../ftp/providers/ftp_provider.dart';
import '../../sync/services/wifi_status_service.dart';

/// ===============================================================
/// OpenBackup
/// File : system_status_provider.dart
/// Version : 1.0.0
/// Description : Dashboard system status provider.
/// ===============================================================

class SystemStatusSnapshot {
  final int configuredFtpServers;
  final int configuredBackupJobs;
  final List<ConnectivityResult> connectivity;
  final String? wifiSsid;
  final int? batteryLevel;
  final BatteryState? batteryState;
  final int? availableStorageBytes;

  const SystemStatusSnapshot({
    required this.configuredFtpServers,
    required this.configuredBackupJobs,
    required this.connectivity,
    required this.wifiSsid,
    required this.batteryLevel,
    required this.batteryState,
    required this.availableStorageBytes,
  });

  bool get isOnline {
    return connectivity.any((result) => result != ConnectivityResult.none);
  }
}

final systemStatusProvider = FutureProvider<SystemStatusSnapshot>((ref) async {
  ref.watch(ftpServerLoadProvider);
  ref.watch(backupJobLoadProvider);

  final ftpServers = ref.watch(ftpServerProvider);
  final backupJobs = ref.watch(backupJobProvider);
  final connectivity = await Connectivity().checkConnectivity();
  final wifiSsid = connectivity.contains(ConnectivityResult.wifi)
      ? await WifiStatusService.currentSsid()
      : null;

  int? batteryLevel;
  BatteryState? batteryState;
  try {
    final battery = Battery();
    batteryLevel = await battery.batteryLevel;
    batteryState = await battery.batteryState;
  } catch (_) {
    batteryLevel = null;
    batteryState = null;
  }

  int? availableStorageBytes;
  try {
    final directory = await getApplicationDocumentsDirectory();
    availableStorageBytes = await _availableStorageBytes(directory.path);
  } catch (_) {
    availableStorageBytes = null;
  }

  return SystemStatusSnapshot(
    configuredFtpServers: ftpServers.length,
    configuredBackupJobs: backupJobs.length,
    connectivity: connectivity,
    wifiSsid: wifiSsid,
    batteryLevel: batteryLevel,
    batteryState: batteryState,
    availableStorageBytes: availableStorageBytes,
  );
});

Future<int?> _availableStorageBytes(String path) async {
  if (!Platform.isAndroid) {
    return null;
  }

  final result = await Process.run('df', ['-k', path]);
  if (result.exitCode != 0) {
    return null;
  }

  final lines = result.stdout.toString().trim().split('\n');
  if (lines.length < 2) {
    return null;
  }

  final columns = lines.last.trim().split(RegExp(r'\s+'));
  if (columns.length < 4) {
    return null;
  }

  final availableKilobytes = int.tryParse(columns[3]);
  if (availableKilobytes == null) {
    return null;
  }

  return availableKilobytes * 1024;
}
