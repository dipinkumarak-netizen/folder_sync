// ===============================================================
// OpenBackup
// File : transfer_progress_snapshot.dart
// Version : 1.0.0
// Description : Shared transfer progress snapshot for backup, sync, restore.
// ===============================================================

class TransferProgressSnapshot {
  final String title;
  final String status;
  final String currentFilePath;
  final int processedFiles;
  final int totalFiles;
  final int processedBytes;
  final DateTime startedAt;
  final DateTime updatedAt;
  final bool active;

  const TransferProgressSnapshot({
    required this.title,
    required this.status,
    required this.currentFilePath,
    required this.processedFiles,
    required this.totalFiles,
    required this.processedBytes,
    required this.startedAt,
    required this.updatedAt,
    required this.active,
  });

  double? get progress {
    if (totalFiles <= 0) {
      return null;
    }

    return (processedFiles / totalFiles).clamp(0, 1).toDouble();
  }

  double get averageBytesPerSecond {
    final elapsedMilliseconds = updatedAt.difference(startedAt).inMilliseconds;
    if (elapsedMilliseconds <= 0 || processedBytes <= 0) {
      return 0;
    }

    return processedBytes / (elapsedMilliseconds / 1000);
  }

  String notificationMessage() {
    final count = totalFiles > 0
        ? '$processedFiles/$totalFiles'
        : '$processedFiles file(s)';
    final speed = '${_formatBytes(averageBytesPerSecond.round())}/s LAN';
    final file = currentFilePath.isEmpty
        ? ''
        : ' - ${_compactPath(currentFilePath)}';
    return '$status - $count - $speed$file';
  }

  TransferProgressSnapshot copyWith({
    String? title,
    String? status,
    String? currentFilePath,
    int? processedFiles,
    int? totalFiles,
    int? processedBytes,
    DateTime? startedAt,
    DateTime? updatedAt,
    bool? active,
  }) {
    return TransferProgressSnapshot(
      title: title ?? this.title,
      status: status ?? this.status,
      currentFilePath: currentFilePath ?? this.currentFilePath,
      processedFiles: processedFiles ?? this.processedFiles,
      totalFiles: totalFiles ?? this.totalFiles,
      processedBytes: processedBytes ?? this.processedBytes,
      startedAt: startedAt ?? this.startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      active: active ?? this.active,
    );
  }

  static String _compactPath(String value) {
    if (value.length <= 36) {
      return value;
    }

    return '...${value.substring(value.length - 33)}';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }

    final mb = kb / 1024;
    if (mb < 1024) {
      return '${mb.toStringAsFixed(1)} MB';
    }

    return '${(mb / 1024).toStringAsFixed(1)} GB';
  }
}
