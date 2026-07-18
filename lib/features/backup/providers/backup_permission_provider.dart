import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// ===============================================================
/// OpenBackup
/// File : backup_permission_provider.dart
/// Version : 1.0.0
/// Description : Runtime permission state for backup foreground work.
/// ===============================================================

class BackupPermissionState {
  final bool notificationGranted;
  final bool notificationPermanentlyDenied;

  const BackupPermissionState({
    required this.notificationGranted,
    required this.notificationPermanentlyDenied,
  });

  bool get canShowForegroundProgress => notificationGranted;
}

class BackupPermissionNotifier
    extends StateNotifier<AsyncValue<BackupPermissionState>> {
  BackupPermissionNotifier() : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_readState);
  }

  Future<void> requestNotificationPermission() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await Permission.notification.request();
      return _readState();
    });
  }

  Future<BackupPermissionState> _readState() async {
    final status = await Permission.notification.status;
    return BackupPermissionState(
      notificationGranted: status.isGranted,
      notificationPermanentlyDenied: status.isPermanentlyDenied,
    );
  }
}

final backupPermissionProvider =
    StateNotifierProvider<
      BackupPermissionNotifier,
      AsyncValue<BackupPermissionState>
    >((ref) {
      return BackupPermissionNotifier();
    });
