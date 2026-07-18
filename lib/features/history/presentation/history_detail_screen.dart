import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/widgets/ob_card.dart';
import '../models/history_entry_model.dart';

/// ===============================================================
/// OpenBackup
/// File : history_detail_screen.dart
/// Version : 1.0.0
/// Description : Detailed operation history and per-run file report screen.
/// ===============================================================

class HistoryDetailScreen extends StatelessWidget {
  const HistoryDetailScreen({super.key, required this.entry});

  final HistoryEntryModel entry;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(entry.status);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('History Details')),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.paddingM),
        children: [
          OBCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: statusColor.withValues(alpha: 0.15),
                      child: Icon(
                        _operationIcon(entry.operationType),
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: AppSizes.paddingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSizes.paddingXS),
                          Text(
                            _dateLabel(entry.createdAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.paddingM),
                Text(entry.message),
                const SizedBox(height: AppSizes.paddingM),
                _DetailRow(label: 'Status', value: _statusLabel(entry.status)),
                _DetailRow(
                  label: 'Operation',
                  value: _operationLabel(entry.operationType),
                ),
                _DetailRow(label: 'Files', value: '${entry.filesChanged}'),
                _DetailRow(
                  label: 'Bytes',
                  value: _formatBytes(entry.bytesChanged),
                ),
                _DetailRow(label: 'Source', value: entry.sourcePath),
                _DetailRow(label: 'Target', value: entry.targetPath),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.paddingM),
          OBCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'File Report',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSizes.paddingM),
                if (entry.fileReports.isEmpty)
                  Text(
                    'No per-file report was recorded for this run.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.textHint),
                  )
                else
                  ...entry.fileReports.map((item) {
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        _actionIcon(item.action),
                        color: _actionColor(item.action),
                      ),
                      title: Text(item.relativePath),
                      subtitle: Text(
                        [
                          item.action,
                          if (item.size > 0) _formatBytes(item.size),
                          if (item.message.isNotEmpty) item.message,
                        ].join(' - '),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(HistoryEntryStatus status) {
    return switch (status) {
      HistoryEntryStatus.success => AppColors.success,
      HistoryEntryStatus.failed => AppColors.error,
      HistoryEntryStatus.cancelled => AppColors.warning,
    };
  }

  String _statusLabel(HistoryEntryStatus status) {
    return switch (status) {
      HistoryEntryStatus.success => 'Success',
      HistoryEntryStatus.failed => 'Failed',
      HistoryEntryStatus.cancelled => 'Cancelled',
    };
  }

  IconData _operationIcon(HistoryOperationType type) {
    return switch (type) {
      HistoryOperationType.backup => AppIcons.backup,
      HistoryOperationType.sync => AppIcons.sync,
      HistoryOperationType.restore => AppIcons.restore,
    };
  }

  String _operationLabel(HistoryOperationType type) {
    return switch (type) {
      HistoryOperationType.backup => 'Backup',
      HistoryOperationType.sync => 'Sync',
      HistoryOperationType.restore => 'Restore',
    };
  }

  IconData _actionIcon(String action) {
    return switch (action) {
      'upload' => AppIcons.upload,
      'download' => AppIcons.download,
      'delete' => AppIcons.delete,
      'skip' => AppIcons.warning,
      'overwrite' => AppIcons.refresh,
      'copy' => AppIcons.files,
      _ => AppIcons.files,
    };
  }

  Color _actionColor(String action) {
    return switch (action) {
      'upload' || 'download' || 'copy' => AppColors.success,
      'delete' || 'overwrite' => AppColors.warning,
      'skip' => AppColors.textHint,
      _ => AppColors.info,
    };
  }

  String _dateLabel(DateTime date) {
    return '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)} '
        '${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  String _formatBytes(int bytes) {
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.paddingS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textHint),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
