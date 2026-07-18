// ===============================================================
// OpenBackup
// File : backup_job_model.dart
// Version : 1.0.0
// Description : Backup job model for local-folder to FTP backups.
// ===============================================================

enum BackupJobStatus { idle, running, success, failed }

enum BackupScheduleRule { manualOnly, hourly, daily }

class BackupJobModel {
  final String id;
  final String name;
  final String localFolderPath;
  final String ftpServerId;
  final String remoteFolderPath;
  final bool enabled;
  final BackupScheduleRule scheduleRule;
  final BackupJobStatus status;
  final DateTime? lastRunAt;
  final String lastMessage;
  final int lastFilesBackedUp;
  final int totalFilesBackedUp;
  final int totalBytesBackedUp;
  final List<String> backedUpRelativePaths;

  const BackupJobModel({
    required this.id,
    required this.name,
    required this.localFolderPath,
    required this.ftpServerId,
    required this.remoteFolderPath,
    this.enabled = true,
    this.scheduleRule = BackupScheduleRule.manualOnly,
    this.status = BackupJobStatus.idle,
    this.lastRunAt,
    this.lastMessage = 'Not run yet',
    this.lastFilesBackedUp = 0,
    this.totalFilesBackedUp = 0,
    this.totalBytesBackedUp = 0,
    this.backedUpRelativePaths = const [],
  });

  BackupJobModel copyWith({
    String? id,
    String? name,
    String? localFolderPath,
    String? ftpServerId,
    String? remoteFolderPath,
    bool? enabled,
    BackupScheduleRule? scheduleRule,
    BackupJobStatus? status,
    DateTime? lastRunAt,
    String? lastMessage,
    int? lastFilesBackedUp,
    int? totalFilesBackedUp,
    int? totalBytesBackedUp,
    List<String>? backedUpRelativePaths,
  }) {
    return BackupJobModel(
      id: id ?? this.id,
      name: name ?? this.name,
      localFolderPath: localFolderPath ?? this.localFolderPath,
      ftpServerId: ftpServerId ?? this.ftpServerId,
      remoteFolderPath: remoteFolderPath ?? this.remoteFolderPath,
      enabled: enabled ?? this.enabled,
      scheduleRule: scheduleRule ?? this.scheduleRule,
      status: status ?? this.status,
      lastRunAt: lastRunAt ?? this.lastRunAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastFilesBackedUp: lastFilesBackedUp ?? this.lastFilesBackedUp,
      totalFilesBackedUp: totalFilesBackedUp ?? this.totalFilesBackedUp,
      totalBytesBackedUp: totalBytesBackedUp ?? this.totalBytesBackedUp,
      backedUpRelativePaths:
          backedUpRelativePaths ??
          List.unmodifiable(this.backedUpRelativePaths),
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
      'scheduleRule': scheduleRule.name,
      'status': status.name,
      'lastRunAt': lastRunAt?.toIso8601String(),
      'lastMessage': lastMessage,
      'lastFilesBackedUp': lastFilesBackedUp,
      'totalFilesBackedUp': totalFilesBackedUp,
      'totalBytesBackedUp': totalBytesBackedUp,
      'backedUpRelativePaths': backedUpRelativePaths,
    };
  }

  factory BackupJobModel.fromJson(Map<String, dynamic> json) {
    final status = BackupJobStatus.values.firstWhere(
      (value) => value.name == json['status'],
      orElse: () => BackupJobStatus.idle,
    );
    final lastRunAtValue = json['lastRunAt'] as String?;

    return BackupJobModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      localFolderPath: json['localFolderPath'] as String? ?? '',
      ftpServerId: json['ftpServerId'] as String? ?? '',
      remoteFolderPath: json['remoteFolderPath'] as String? ?? '/',
      enabled: json['enabled'] as bool? ?? true,
      scheduleRule: _enumValue(
        BackupScheduleRule.values,
        json['scheduleRule'],
        BackupScheduleRule.manualOnly,
      ),
      status: status == BackupJobStatus.running ? BackupJobStatus.idle : status,
      lastRunAt: lastRunAtValue == null
          ? null
          : DateTime.tryParse(lastRunAtValue),
      lastMessage: json['lastMessage'] as String? ?? 'Not run yet',
      lastFilesBackedUp: json['lastFilesBackedUp'] as int? ?? 0,
      totalFilesBackedUp: json['totalFilesBackedUp'] as int? ?? 0,
      totalBytesBackedUp: json['totalBytesBackedUp'] as int? ?? 0,
      backedUpRelativePaths:
          (json['backedUpRelativePaths'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList(),
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
