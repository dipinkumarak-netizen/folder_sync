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
  final bool storageGranted;
  final bool storagePermanentlyDenied;

  const BackupPermissionState({
    required this.notificationGranted,
    required this.notificationPermanentlyDenied,
    required this.storageGranted,
    required this.storagePermanentlyDenied,
  });

  bool get canShowForegroundProgress => notificationGranted;
  bool get canAccessFiles => storageGranted;
  bool get allReady => notificationGranted && storageGranted;
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

  Future<void> requestStoragePermission() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      if (await Permission.storage.request().isDenied) {
        await Permission.manageExternalStorage.request();
      }
      return _readState();
    });
  }

  Future<BackupPermissionState> _readState() async {
    final notificationStatus = await Permission.notification.status;
    final storageStatus = await Permission.storage.status;
    final manageStorageStatus = await Permission.manageExternalStorage.status;

    return BackupPermissionState(
      notificationGranted: notificationStatus.isGranted,
      notificationPermanentlyDenied: notificationStatus.isPermanentlyDenied,
      storageGranted: storageStatus.isGranted || manageStorageStatus.isGranted,
      storagePermanentlyDenied:
          storageStatus.isPermanentlyDenied ||
          manageStorageStatus.isPermanentlyDenied,
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
