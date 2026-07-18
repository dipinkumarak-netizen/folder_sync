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
  final DateTime? lastRunAt;
  final String lastMessage;

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
    this.lastRunAt,
    this.lastMessage = 'Not run yet',
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
    DateTime? lastRunAt,
    String? lastMessage,
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
      lastRunAt: lastRunAt ?? this.lastRunAt,
      lastMessage: lastMessage ?? this.lastMessage,
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
      'lastRunAt': lastRunAt?.toIso8601String(),
      'lastMessage': lastMessage,
    };
  }

  factory SyncRuleModel.fromJson(Map<String, dynamic> json) {
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
      lastRunAt: DateTime.tryParse(json['lastRunAt'] as String? ?? ''),
      lastMessage: json['lastMessage'] as String? ?? 'Not run yet',
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
