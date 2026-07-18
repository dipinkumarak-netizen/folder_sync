// ===============================================================
// OpenBackup
// File : backup_job_model.dart
// Version : 1.0.0
// Description : Backup job model for local-folder to FTP backups.
// ===============================================================

enum BackupJobStatus { idle, running, success, failed }

class BackupJobModel {
  final String id;
  final String name;
  final String localFolderPath;
  final String ftpServerId;
  final String remoteFolderPath;
  final bool enabled;
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
}
