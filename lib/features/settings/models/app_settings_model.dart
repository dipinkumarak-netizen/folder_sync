// ===============================================================
// OpenBackup
// File : app_settings_model.dart
// Version : 1.0.0
// Description : Persistent application settings model.
// ===============================================================

class AppSettingsModel {
  final bool automaticSchedulingEnabled;
  final bool defaultBackupWifiOnly;
  final bool defaultSyncWifiOnly;
  final bool showForegroundNotifications;
  final bool onboardingCompleted;
  final bool biometricLockEnabled;

  const AppSettingsModel({
    this.automaticSchedulingEnabled = true,
    this.defaultBackupWifiOnly = true,
    this.defaultSyncWifiOnly = true,
    this.showForegroundNotifications = true,
    this.onboardingCompleted = false,
    this.biometricLockEnabled = false,
  });

  AppSettingsModel copyWith({
    bool? automaticSchedulingEnabled,
    bool? defaultBackupWifiOnly,
    bool? defaultSyncWifiOnly,
    bool? showForegroundNotifications,
    bool? onboardingCompleted,
    bool? biometricLockEnabled,
  }) {
    return AppSettingsModel(
      automaticSchedulingEnabled:
          automaticSchedulingEnabled ?? this.automaticSchedulingEnabled,
      defaultBackupWifiOnly:
          defaultBackupWifiOnly ?? this.defaultBackupWifiOnly,
      defaultSyncWifiOnly: defaultSyncWifiOnly ?? this.defaultSyncWifiOnly,
      showForegroundNotifications:
          showForegroundNotifications ?? this.showForegroundNotifications,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      biometricLockEnabled: biometricLockEnabled ?? this.biometricLockEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'automaticSchedulingEnabled': automaticSchedulingEnabled,
      'defaultBackupWifiOnly': defaultBackupWifiOnly,
      'defaultSyncWifiOnly': defaultSyncWifiOnly,
      'showForegroundNotifications': showForegroundNotifications,
      'onboardingCompleted': onboardingCompleted,
      'biometricLockEnabled': biometricLockEnabled,
    };
  }

  factory AppSettingsModel.fromJson(Map<String, dynamic> json) {
    return AppSettingsModel(
      automaticSchedulingEnabled:
          json['automaticSchedulingEnabled'] as bool? ?? true,
      defaultBackupWifiOnly: json['defaultBackupWifiOnly'] as bool? ?? true,
      defaultSyncWifiOnly: json['defaultSyncWifiOnly'] as bool? ?? true,
      showForegroundNotifications:
          json['showForegroundNotifications'] as bool? ?? true,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      biometricLockEnabled: json['biometricLockEnabled'] as bool? ?? false,
    );
  }
}
