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

  const AppSettingsModel({
    this.automaticSchedulingEnabled = true,
    this.defaultBackupWifiOnly = true,
    this.defaultSyncWifiOnly = true,
    this.showForegroundNotifications = true,
  });

  AppSettingsModel copyWith({
    bool? automaticSchedulingEnabled,
    bool? defaultBackupWifiOnly,
    bool? defaultSyncWifiOnly,
    bool? showForegroundNotifications,
  }) {
    return AppSettingsModel(
      automaticSchedulingEnabled:
          automaticSchedulingEnabled ?? this.automaticSchedulingEnabled,
      defaultBackupWifiOnly:
          defaultBackupWifiOnly ?? this.defaultBackupWifiOnly,
      defaultSyncWifiOnly: defaultSyncWifiOnly ?? this.defaultSyncWifiOnly,
      showForegroundNotifications:
          showForegroundNotifications ?? this.showForegroundNotifications,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'automaticSchedulingEnabled': automaticSchedulingEnabled,
      'defaultBackupWifiOnly': defaultBackupWifiOnly,
      'defaultSyncWifiOnly': defaultSyncWifiOnly,
      'showForegroundNotifications': showForegroundNotifications,
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
    );
  }
}
