import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/widgets/ob_card.dart';
import '../models/history_entry_model.dart';
import '../providers/history_provider.dart';
import 'history_detail_screen.dart';

/// ===============================================================
/// OpenBackup
/// File : history_screen.dart
/// Version : 1.0.0
/// Description : Backup and synchronization history screen.
/// ===============================================================

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  HistoryOperationType? _filter;

  @override
  Widget build(BuildContext context) {
    ref.watch(historyLoadProvider);
    final entries = ref.watch(historyProvider);
    final filteredEntries = _filter == null
        ? entries
        : entries.where((entry) => entry.operationType == _filter).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            tooltip: 'Clear History',
            icon: const Icon(AppIcons.delete),
            onPressed: entries.isEmpty ? null : () => _confirmClear(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.paddingM),
        children: [
          _HistorySummary(entries: entries),
          const SizedBox(height: AppSizes.paddingM),
          _HistoryFilters(
            selected: _filter,
            onChanged: (value) => setState(() => _filter = value),
          ),
          const SizedBox(height: AppSizes.paddingM),
          if (filteredEntries.isEmpty)
            const _EmptyHistory()
          else
            ...filteredEntries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.paddingM),
                child: _HistoryEntryTile(
                  entry: entry,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HistoryDetailScreen(entry: entry),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear History'),
          content: const Text('Delete all backup and sync history entries?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (shouldClear == true) {
      await ref.read(historyProvider.notifier).clearEntries();
    }
  }
}

class _HistorySummary extends StatelessWidget {
  const _HistorySummary({required this.entries});

  final List<HistoryEntryModel> entries;

  @override
  Widget build(BuildContext context) {
    final successCount = entries
        .where((entry) => entry.status == HistoryEntryStatus.success)
        .length;
    final failedCount = entries
        .where((entry) => entry.status == HistoryEntryStatus.failed)
        .length;

    return OBCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Operation History',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSizes.paddingM),
          Wrap(
            spacing: AppSizes.paddingS,
            runSpacing: AppSizes.paddingS,
            children: [
              _HistoryBadge(
                label: '${entries.length} total',
                color: AppColors.info,
              ),
              _HistoryBadge(
                label: '$successCount success',
                color: AppColors.success,
              ),
              _HistoryBadge(
                label: '$failedCount failed',
                color: AppColors.error,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryFilters extends StatelessWidget {
  const _HistoryFilters({required this.selected, required this.onChanged});

  final HistoryOperationType? selected;
  final ValueChanged<HistoryOperationType?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSizes.paddingS,
      runSpacing: AppSizes.paddingS,
      children: [
        ChoiceChip(
          label: const Text('All'),
          selected: selected == null,
          onSelected: (_) => onChanged(null),
        ),
        ChoiceChip(
          label: const Text('Backup'),
          selected: selected == HistoryOperationType.backup,
          onSelected: (_) => onChanged(HistoryOperationType.backup),
        ),
        ChoiceChip(
          label: const Text('Sync'),
          selected: selected == HistoryOperationType.sync,
          onSelected: (_) => onChanged(HistoryOperationType.sync),
        ),
        ChoiceChip(
          label: const Text('Restore'),
          selected: selected == HistoryOperationType.restore,
          onSelected: (_) => onChanged(HistoryOperationType.restore),
        ),
      ],
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return OBCard(
      child: Column(
        children: [
          const Icon(AppIcons.history, size: 60, color: AppColors.history),
          const SizedBox(height: AppSizes.paddingM),
          Text(
            'No History Yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSizes.paddingS),
          Text(
            'Completed backup, sync, and restore operations will appear here.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}

class _HistoryEntryTile extends StatelessWidget {
  const _HistoryEntryTile({required this.entry, required this.onTap});

  final HistoryEntryModel entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(entry.status);

    return OBCard(
      onTap: onTap,
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
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSizes.paddingXS),
                    Text(
                      _dateLabel(entry.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              _HistoryBadge(
                label: _statusLabel(entry.status),
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingM),
          Text(entry.message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSizes.paddingM),
          _PathRow(icon: AppIcons.folder, text: entry.sourcePath),
          const SizedBox(height: AppSizes.paddingS),
          _PathRow(icon: AppIcons.upload, text: entry.targetPath),
          const SizedBox(height: AppSizes.paddingM),
          Wrap(
            spacing: AppSizes.paddingS,
            runSpacing: AppSizes.paddingS,
            children: [
              _HistoryBadge(
                label: _operationLabel(entry.operationType),
                color: AppColors.info,
              ),
              _HistoryBadge(
                label: '${entry.filesChanged} file(s)',
                color: AppColors.success,
              ),
              _HistoryBadge(
                label: _formatBytes(entry.bytesChanged),
                color: AppColors.history,
              ),
            ],
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

class _PathRow extends StatelessWidget {
  const _PathRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: AppSizes.iconS, color: AppColors.textHint),
        const SizedBox(width: AppSizes.paddingS),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _HistoryBadge extends StatelessWidget {
  const _HistoryBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingS,
        vertical: AppSizes.paddingXS,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
      ),
    );
  }
}
