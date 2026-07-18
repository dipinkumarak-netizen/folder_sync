// ===============================================================
// OpenBackup
// File : sync_rule_model.dart
// Version : 1.0.0
// Description : Synchronization rule model.
// ===============================================================

enum SyncDirection {
  uploadOnly,
  downloadOnly,
  twoWay,
  mirrorLocalToRemote,
  mirrorRemoteToLocal,
}

enum SyncConflictRule { newerWins, localWins, remoteWins, keepBoth, skip }

enum SyncDeleteRule {
  keepDeletedFiles,
  deleteRemoteWhenLocalDeleted,
  deleteLocalWhenRemoteDeleted,
  deleteBothWays,
}

enum SyncTriggerRule { manualOnly, onHomeWifi, hourly, daily }

enum SyncRuleStatus { idle, running, success, failed }

class SyncRuleModel {
  final String id;
  final String name;
  final String localFolderPath;
  final String ftpServerId;
  final String remoteFolderPath;
  final bool enabled;
  final SyncDirection direction;
  final SyncConflictRule conflictRule;
  final SyncDeleteRule deleteRule;
  final SyncTriggerRule triggerRule;
  final bool syncSubfolders;
  final bool includeHiddenFiles;
  final bool runOnWifiOnly;
  final String homeWifiName;
  final String includePatterns;
  final String excludePatterns;
  final int? maxFileSizeMb;
  final SyncRuleStatus status;
  final DateTime? lastRunAt;
  final String lastMessage;
  final int lastFilesChanged;
  final int totalFilesChanged;
  final int totalBytesChanged;

  const SyncRuleModel({
    required this.id,
    required this.name,
    required this.localFolderPath,
    required this.ftpServerId,
    required this.remoteFolderPath,
    this.enabled = true,
    this.direction = SyncDirection.twoWay,
    this.conflictRule = SyncConflictRule.newerWins,
    this.deleteRule = SyncDeleteRule.keepDeletedFiles,
    this.triggerRule = SyncTriggerRule.manualOnly,
    this.syncSubfolders = true,
    this.includeHiddenFiles = false,
    this.runOnWifiOnly = true,
    this.homeWifiName = '',
    this.includePatterns = '*',
    this.excludePatterns = '',
    this.maxFileSizeMb,
    this.status = SyncRuleStatus.idle,
    this.lastRunAt,
    this.lastMessage = 'Not run yet',
    this.lastFilesChanged = 0,
    this.totalFilesChanged = 0,
    this.totalBytesChanged = 0,
  });

  SyncRuleModel copyWith({
    String? id,
    String? name,
    String? localFolderPath,
    String? ftpServerId,
    String? remoteFolderPath,
    bool? enabled,
    SyncDirection? direction,
    SyncConflictRule? conflictRule,
    SyncDeleteRule? deleteRule,
    SyncTriggerRule? triggerRule,
    bool? syncSubfolders,
    bool? includeHiddenFiles,
    bool? runOnWifiOnly,
    String? homeWifiName,
    String? includePatterns,
    String? excludePatterns,
    int? maxFileSizeMb,
    bool clearMaxFileSize = false,
    SyncRuleStatus? status,
    DateTime? lastRunAt,
    String? lastMessage,
    int? lastFilesChanged,
    int? totalFilesChanged,
    int? totalBytesChanged,
  }) {
    return SyncRuleModel(
      id: id ?? this.id,
      name: name ?? this.name,
      localFolderPath: localFolderPath ?? this.localFolderPath,
      ftpServerId: ftpServerId ?? this.ftpServerId,
      remoteFolderPath: remoteFolderPath ?? this.remoteFolderPath,
      enabled: enabled ?? this.enabled,
      direction: direction ?? this.direction,
      conflictRule: conflictRule ?? this.conflictRule,
      deleteRule: deleteRule ?? this.deleteRule,
      triggerRule: triggerRule ?? this.triggerRule,
      syncSubfolders: syncSubfolders ?? this.syncSubfolders,
      includeHiddenFiles: includeHiddenFiles ?? this.includeHiddenFiles,
      runOnWifiOnly: runOnWifiOnly ?? this.runOnWifiOnly,
      homeWifiName: homeWifiName ?? this.homeWifiName,
      includePatterns: includePatterns ?? this.includePatterns,
      excludePatterns: excludePatterns ?? this.excludePatterns,
      maxFileSizeMb: clearMaxFileSize
          ? null
          : maxFileSizeMb ?? this.maxFileSizeMb,
      status: status ?? this.status,
      lastRunAt: lastRunAt ?? this.lastRunAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastFilesChanged: lastFilesChanged ?? this.lastFilesChanged,
      totalFilesChanged: totalFilesChanged ?? this.totalFilesChanged,
      totalBytesChanged: totalBytesChanged ?? this.totalBytesChanged,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'localFolderPath': localFolderPath,
      'ftpServerId': ftpServerId,
      'remoteFolderPath': remoteFolderPath,
      'enabled': enabled,
      'direction': direction.name,
      'conflictRule': conflictRule.name,
      'deleteRule': deleteRule.name,
      'triggerRule': triggerRule.name,
      'syncSubfolders': syncSubfolders,
      'includeHiddenFiles': includeHiddenFiles,
      'runOnWifiOnly': runOnWifiOnly,
      'homeWifiName': homeWifiName,
      'includePatterns': includePatterns,
      'excludePatterns': excludePatterns,
      'maxFileSizeMb': maxFileSizeMb,
      'status': status.name,
      'lastRunAt': lastRunAt?.toIso8601String(),
      'lastMessage': lastMessage,
      'lastFilesChanged': lastFilesChanged,
      'totalFilesChanged': totalFilesChanged,
      'totalBytesChanged': totalBytesChanged,
    };
  }

  factory SyncRuleModel.fromJson(Map<String, dynamic> json) {
    final status = _enumValue(
      SyncRuleStatus.values,
      json['status'],
      SyncRuleStatus.idle,
    );

    return SyncRuleModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      localFolderPath: json['localFolderPath'] as String? ?? '',
      ftpServerId: json['ftpServerId'] as String? ?? '',
      remoteFolderPath: json['remoteFolderPath'] as String? ?? '/',
      enabled: json['enabled'] as bool? ?? true,
      direction: _enumValue(
        SyncDirection.values,
        json['direction'],
        SyncDirection.twoWay,
      ),
      conflictRule: _enumValue(
        SyncConflictRule.values,
        json['conflictRule'],
        SyncConflictRule.newerWins,
      ),
      deleteRule: _enumValue(
        SyncDeleteRule.values,
        json['deleteRule'],
        SyncDeleteRule.keepDeletedFiles,
      ),
      triggerRule: _enumValue(
        SyncTriggerRule.values,
        json['triggerRule'],
        SyncTriggerRule.manualOnly,
      ),
      syncSubfolders: json['syncSubfolders'] as bool? ?? true,
      includeHiddenFiles: json['includeHiddenFiles'] as bool? ?? false,
      runOnWifiOnly: json['runOnWifiOnly'] as bool? ?? true,
      homeWifiName: json['homeWifiName'] as String? ?? '',
      includePatterns: json['includePatterns'] as String? ?? '*',
      excludePatterns: json['excludePatterns'] as String? ?? '',
      maxFileSizeMb: json['maxFileSizeMb'] as int?,
      status: status == SyncRuleStatus.running ? SyncRuleStatus.idle : status,
      lastRunAt: DateTime.tryParse(json['lastRunAt'] as String? ?? ''),
      lastMessage: json['lastMessage'] as String? ?? 'Not run yet',
      lastFilesChanged: json['lastFilesChanged'] as int? ?? 0,
      totalFilesChanged: json['totalFilesChanged'] as int? ?? 0,
      totalBytesChanged: json['totalBytesChanged'] as int? ?? 0,
    );
  }

  static T _enumValue<T extends Enum>(
    List<T> values,
    Object? name,
    T fallback,
  ) {
    return values.firstWhere(
      (value) => value.name == name,
      orElse: () => fallback,
    );
  }
}
