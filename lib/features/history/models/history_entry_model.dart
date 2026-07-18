// ===============================================================
// OpenBackup
// File : history_entry_model.dart
// Version : 1.0.0
// Description : Backup and synchronization history entry model.
// ===============================================================

enum HistoryOperationType { backup, sync, restore }

enum HistoryEntryStatus { success, failed, cancelled }

class HistoryFileReportItem {
  final String relativePath;
  final String action;
  final int size;
  final String message;

  const HistoryFileReportItem({
    required this.relativePath,
    required this.action,
    this.size = 0,
    this.message = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'relativePath': relativePath,
      'action': action,
      'size': size,
      'message': message,
    };
  }

  factory HistoryFileReportItem.fromJson(Map<String, dynamic> json) {
    return HistoryFileReportItem(
      relativePath: json['relativePath'] as String? ?? '',
      action: json['action'] as String? ?? '',
      size: json['size'] as int? ?? 0,
      message: json['message'] as String? ?? '',
    );
  }
}

class HistoryEntryModel {
  final String id;
  final HistoryOperationType operationType;
  final HistoryEntryStatus status;
  final String title;
  final String message;
  final String sourcePath;
  final String targetPath;
  final String relatedId;
  final DateTime createdAt;
  final int filesChanged;
  final int bytesChanged;
  final List<HistoryFileReportItem> fileReports;

  const HistoryEntryModel({
    required this.id,
    required this.operationType,
    required this.status,
    required this.title,
    required this.message,
    required this.sourcePath,
    required this.targetPath,
    required this.relatedId,
    required this.createdAt,
    this.filesChanged = 0,
    this.bytesChanged = 0,
    this.fileReports = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'operationType': operationType.name,
      'status': status.name,
      'title': title,
      'message': message,
      'sourcePath': sourcePath,
      'targetPath': targetPath,
      'relatedId': relatedId,
      'createdAt': createdAt.toIso8601String(),
      'filesChanged': filesChanged,
      'bytesChanged': bytesChanged,
      'fileReports': fileReports.map((item) => item.toJson()).toList(),
    };
  }

  factory HistoryEntryModel.fromJson(Map<String, dynamic> json) {
    return HistoryEntryModel(
      id: json['id'] as String? ?? '',
      operationType: _enumValue(
        HistoryOperationType.values,
        json['operationType'],
        HistoryOperationType.backup,
      ),
      status: _enumValue(
        HistoryEntryStatus.values,
        json['status'],
        HistoryEntryStatus.failed,
      ),
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      sourcePath: json['sourcePath'] as String? ?? '',
      targetPath: json['targetPath'] as String? ?? '',
      relatedId: json['relatedId'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      filesChanged: json['filesChanged'] as int? ?? 0,
      bytesChanged: json['bytesChanged'] as int? ?? 0,
      fileReports: (json['fileReports'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(HistoryFileReportItem.fromJson)
          .where((item) => item.relativePath.isNotEmpty)
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
