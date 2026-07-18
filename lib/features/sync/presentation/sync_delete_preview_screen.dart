import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/widgets/ob_card.dart';
import '../../ftp/models/ftp_server_model.dart';
import '../../repositories/sync_rule_repository.dart';
import '../models/sync_rule_model.dart';
import '../providers/sync_rule_provider.dart';

/// ===============================================================
/// OpenBackup
/// File : sync_delete_preview_screen.dart
/// Version : 1.0.0
/// Description : Protected preview for destructive sync deletes.
/// ===============================================================

class SyncDeletePreviewScreen extends ConsumerStatefulWidget {
  const SyncDeletePreviewScreen({
    super.key,
    required this.rule,
    required this.ftpServer,
  });

  final SyncRuleModel rule;
  final FtpServerModel ftpServer;

  @override
  ConsumerState<SyncDeletePreviewScreen> createState() =>
      _SyncDeletePreviewScreenState();
}

class _SyncDeletePreviewScreenState
    extends ConsumerState<SyncDeletePreviewScreen> {
  late Future<SyncDeletePreviewResult> _previewFuture;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _previewFuture = _loadPreview();
  }

  Future<SyncDeletePreviewResult> _loadPreview() {
    return ref
        .read(syncRuleProvider.notifier)
        .previewDeletes(rule: widget.rule, ftpServer: widget.ftpServer);
  }

  void _refreshPreview() {
    setState(() {
      _previewFuture = _loadPreview();
    });
  }

  Future<void> _confirmAndExecuteDeletes(
    SyncDeletePreviewResult preview,
  ) async {
    if (preview.items.isEmpty || _isDeleting) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Protected Delete'),
          content: Text(
            'Delete ${preview.items.length} file(s) from this sync rule?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    final result = await ref
        .read(syncRuleProvider.notifier)
        .executeProtectedDeletes(
          rule: widget.rule,
          ftpServer: widget.ftpServer,
        );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? AppColors.success : AppColors.error,
      ),
    );

    setState(() {
      _isDeleting = false;
      _previewFuture = _loadPreview();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Delete Preview'),
        actions: [
          IconButton(
            tooltip: 'Refresh Preview',
            onPressed: _refreshPreview,
            icon: const Icon(AppIcons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<SyncDeletePreviewResult>(
        future: _previewFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final result = snapshot.data;
          if (result == null) {
            return const _PreviewMessage(
              icon: AppIcons.error,
              color: AppColors.error,
              title: 'Preview Failed',
              message: 'Delete preview could not be loaded.',
            );
          }

          if (!result.success) {
            return _PreviewMessage(
              icon: AppIcons.error,
              color: AppColors.error,
              title: 'Preview Failed',
              message: result.message,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSizes.paddingM),
            itemCount: result.items.length + 1,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppSizes.paddingM),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _PreviewSummary(
                  rule: widget.rule,
                  ftpServer: widget.ftpServer,
                  result: result,
                  isDeleting: _isDeleting,
                  onExecuteDeletes: () => _confirmAndExecuteDeletes(result),
                );
              }

              return _PreviewItemTile(item: result.items[index - 1]);
            },
          );
        },
      ),
    );
  }
}

class _PreviewSummary extends StatelessWidget {
  const _PreviewSummary({
    required this.rule,
    required this.ftpServer,
    required this.result,
    required this.isDeleting,
    required this.onExecuteDeletes,
  });

  final SyncRuleModel rule;
  final FtpServerModel ftpServer;
  final SyncDeletePreviewResult result;
  final bool isDeleting;
  final VoidCallback onExecuteDeletes;

  @override
  Widget build(BuildContext context) {
    final hasDeletes = result.items.isNotEmpty;
    return OBCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.warning.withValues(alpha: 0.15),
                child: const Icon(AppIcons.warning, color: AppColors.warning),
              ),
              const SizedBox(width: AppSizes.paddingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rule.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSizes.paddingXS),
                    Text(
                      '${ftpServer.name}:${rule.remoteFolderPath}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingM),
          Wrap(
            spacing: AppSizes.paddingS,
            runSpacing: AppSizes.paddingS,
            children: [
              _PreviewBadge(
                label: '${result.items.length} total',
                color: hasDeletes ? AppColors.warning : AppColors.success,
              ),
              _PreviewBadge(
                label: '${result.localDeleteCount} local',
                color: AppColors.info,
              ),
              _PreviewBadge(
                label: '${result.remoteDeleteCount} remote',
                color: AppColors.sync,
              ),
              _PreviewBadge(
                label: _formatBytes(result.totalBytes),
                color: AppColors.textHint,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingM),
          Text(result.message, style: Theme.of(context).textTheme.bodyMedium),
          if (hasDeletes) ...[
            const SizedBox(height: AppSizes.paddingM),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isDeleting ? null : onExecuteDeletes,
                icon: isDeleting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(AppIcons.delete),
                label: Text(isDeleting ? 'Deleting' : 'Confirm Delete'),
              ),
            ),
          ],
          if (!hasDeletes) ...[
            const SizedBox(height: AppSizes.paddingL),
            Center(
              child: Column(
                children: [
                  const Icon(
                    AppIcons.success,
                    size: 56,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: AppSizes.paddingS),
                  Text(
                    'No Deletes Found',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewItemTile extends StatelessWidget {
  const _PreviewItemTile({required this.item});

  final SyncDeletePreviewItem item;

  @override
  Widget build(BuildContext context) {
    final targetColor = item.target == SyncDeleteTarget.local
        ? AppColors.info
        : AppColors.sync;
    final targetLabel = item.target == SyncDeleteTarget.local
        ? 'Local'
        : 'Remote';

    return OBCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.error.withValues(alpha: 0.15),
            child: const Icon(AppIcons.delete, color: AppColors.error),
          ),
          const SizedBox(width: AppSizes.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.relativePath,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSizes.paddingXS),
                Text(
                  '${_formatBytes(item.size)}'
                  '${item.modifiedAt == null ? '' : ' - ${_formatDate(item.modifiedAt!)}'}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textHint),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.paddingS),
          _PreviewBadge(label: targetLabel, color: targetColor),
        ],
      ),
    );
  }
}

class _PreviewMessage extends StatelessWidget {
  const _PreviewMessage({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      children: [
        OBCard(
          child: Column(
            children: [
              Icon(icon, size: 56, color: color),
              const SizedBox(height: AppSizes.paddingM),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSizes.paddingS),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textHint),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge({required this.label, required this.color});

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

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
