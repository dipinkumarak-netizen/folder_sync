import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/widgets/transfer_status_bar.dart';
import '../../../core/widgets/ob_card.dart';
import '../../ftp/models/ftp_server_model.dart';
import '../../ftp/presentation/ftp_server_list_screen.dart';
import '../../ftp/providers/ftp_provider.dart';
import '../models/sync_rule_model.dart';
import '../providers/sync_rule_provider.dart';
import 'sync_delete_preview_screen.dart';
import 'sync_rule_form_screen.dart';

/// ===============================================================
/// OpenBackup
/// File : sync_rule_list_screen.dart
/// Version : 1.0.0
/// Description : Synchronization rule list screen.
/// ===============================================================

class SyncRuleListScreen extends ConsumerWidget {
  const SyncRuleListScreen({super.key});

  void _openForm(BuildContext context, [SyncRuleModel? rule]) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SyncRuleFormScreen(rule: rule)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(syncRuleLoadProvider);
    ref.watch(ftpServerLoadProvider);
    final rules = ref.watch(syncRuleProvider);
    final ftpServers = ref.watch(ftpServerProvider);
    final transferProgress = ref.watch(syncTransferProgressProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Synchronization')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add Sync Rule',
        onPressed: () => _openForm(context),
        child: const Icon(AppIcons.add),
      ),
      body: rules.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              children: [
                _SyncRulesOverview(hasFtpServers: ftpServers.isNotEmpty),
                if (transferProgress?.active == true) ...[
                  const SizedBox(height: AppSizes.paddingM),
                  TransferStatusBar(progress: transferProgress!),
                ],
                const SizedBox(height: AppSizes.paddingM),
                _EmptySyncRules(hasFtpServers: ftpServers.isNotEmpty),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              itemCount: rules.length + 1,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSizes.paddingM),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    children: [
                      _SyncRulesOverview(hasFtpServers: ftpServers.isNotEmpty),
                      if (transferProgress?.active == true) ...[
                        const SizedBox(height: AppSizes.paddingM),
                        TransferStatusBar(progress: transferProgress!),
                      ],
                    ],
                  );
                }

                final rule = rules[index - 1];
                return _SyncRuleTile(
                  rule: rule,
                  ftpServer: _findServer(ftpServers, rule.ftpServerId),
                  onEdit: () => _openForm(context, rule),
                );
              },
            ),
    );
  }

  FtpServerModel? _findServer(List<FtpServerModel> servers, String id) {
    for (final server in servers) {
      if (server.id == id) {
        return server;
      }
    }

    return null;
  }
}

class _SyncRulesOverview extends StatelessWidget {
  const _SyncRulesOverview({required this.hasFtpServers});

  final bool hasFtpServers;

  @override
  Widget build(BuildContext context) {
    return OBCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.sync.withValues(alpha: 0.15),
                child: const Icon(AppIcons.sync, color: AppColors.sync),
              ),
              const SizedBox(width: AppSizes.paddingM),
              Expanded(
                child: Text(
                  'Sync Rules',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingM),
          Wrap(
            spacing: AppSizes.paddingS,
            runSpacing: AppSizes.paddingS,
            children: [
              const _RuleBadge(label: 'Upload', color: AppColors.success),
              const _RuleBadge(label: 'Download', color: AppColors.info),
              const _RuleBadge(label: 'Two-Way', color: AppColors.sync),
              const _RuleBadge(label: 'Mirror', color: AppColors.warning),
              _RuleBadge(
                label: hasFtpServers ? 'FTP Ready' : 'FTP Needed',
                color: hasFtpServers ? AppColors.success : AppColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptySyncRules extends StatelessWidget {
  const _EmptySyncRules({required this.hasFtpServers});

  final bool hasFtpServers;

  @override
  Widget build(BuildContext context) {
    return OBCard(
      child: Column(
        children: [
          const Icon(AppIcons.sync, size: 60, color: AppColors.sync),
          const SizedBox(height: AppSizes.paddingM),
          Text(
            'No Sync Rules',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSizes.paddingS),
          Text(
            hasFtpServers
                ? 'Press the + button to configure synchronization rules.'
                : 'Add an FTP server first, then create a sync rule.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textHint),
          ),
          if (!hasFtpServers) ...[
            const SizedBox(height: AppSizes.paddingL),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FtpServerListScreen(),
                  ),
                );
              },
              icon: const Icon(AppIcons.server),
              label: const Text('Open FTP Servers'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SyncRuleTile extends ConsumerWidget {
  const _SyncRuleTile({
    required this.rule,
    required this.ftpServer,
    required this.onEdit,
  });

  final SyncRuleModel rule;
  final FtpServerModel? ftpServer;
  final VoidCallback onEdit;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Sync Rule'),
          content: Text('Delete "${rule.name}" from your sync rules?'),
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

    if (shouldDelete == true) {
      await ref.read(syncRuleProvider.notifier).deleteRule(rule.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final directionColor = _directionColor(rule.direction);
    final isRunning = rule.status == SyncRuleStatus.running;
    final statusColor = _statusColor(rule.status);
    final showDeletePreview = _needsDeletePreview(rule);

    return OBCard(
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: directionColor.withValues(alpha: 0.15),
                child: Icon(AppIcons.sync, color: directionColor),
              ),
              const SizedBox(width: AppSizes.paddingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rule.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSizes.paddingXS),
                    Text(
                      ftpServer?.name ?? 'Missing FTP server',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: rule.enabled,
                onChanged: isRunning
                    ? null
                    : (value) {
                        ref
                            .read(syncRuleProvider.notifier)
                            .toggleRule(rule.id, value);
                      },
              ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingM),
          _InfoRow(icon: AppIcons.folder, text: rule.localFolderPath),
          const SizedBox(height: AppSizes.paddingS),
          _InfoRow(icon: AppIcons.upload, text: rule.remoteFolderPath),
          const SizedBox(height: AppSizes.paddingM),
          Wrap(
            spacing: AppSizes.paddingS,
            runSpacing: AppSizes.paddingS,
            children: [
              _RuleBadge(
                label: _directionLabel(rule.direction),
                color: directionColor,
              ),
              _RuleBadge(
                label: _conflictLabel(rule.conflictRule),
                color: AppColors.info,
              ),
              _RuleBadge(
                label: _deleteLabel(rule.deleteRule),
                color: AppColors.warning,
              ),
              _RuleBadge(
                label: _triggerLabel(rule.triggerRule),
                color: AppColors.schedule,
              ),
              _RuleBadge(label: _statusLabel(rule.status), color: statusColor),
              _RuleBadge(
                label: '${rule.totalFilesChanged} file(s)',
                color: AppColors.info,
              ),
              if (rule.runOnWifiOnly)
                const _RuleBadge(label: 'Wi-Fi Only', color: AppColors.success),
              if (rule.homeWifiName.isNotEmpty)
                _RuleBadge(label: rule.homeWifiName, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: AppSizes.paddingM),
          Text(rule.lastMessage, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSizes.paddingM),
          if (showDeletePreview) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isRunning ? null : () => _openDeletePreview(context),
                icon: const Icon(AppIcons.warning),
                label: const Text('Preview Deletes'),
              ),
            ),
            const SizedBox(height: AppSizes.paddingS),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isRunning ? null : () => _runSync(context, ref),
                  icon: isRunning
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(AppIcons.sync),
                  label: Text(isRunning ? 'Running' : 'Run Sync'),
                ),
              ),
              const SizedBox(width: AppSizes.paddingS),
              IconButton(
                tooltip: 'Edit Sync Rule',
                icon: const Icon(AppIcons.edit),
                onPressed: isRunning ? null : onEdit,
              ),
              IconButton(
                tooltip: 'Delete Sync Rule',
                icon: const Icon(AppIcons.delete),
                color: AppColors.error,
                onPressed: isRunning
                    ? null
                    : () => _confirmDelete(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openDeletePreview(BuildContext context) {
    final server = ftpServer;
    if (server == null) {
      _showMessage(
        context,
        'The selected FTP server is not available.',
        AppColors.error,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SyncDeletePreviewScreen(rule: rule, ftpServer: server),
      ),
    );
  }

  Future<void> _runSync(BuildContext context, WidgetRef ref) async {
    final server = ftpServer;
    if (server == null) {
      _showMessage(
        context,
        'The selected FTP server is not available.',
        AppColors.error,
      );
      return;
    }

    final result = await ref
        .read(syncRuleProvider.notifier)
        .runRule(rule: rule, ftpServer: server);

    if (!context.mounted) {
      return;
    }

    _showMessage(
      context,
      result.message,
      result.success ? AppColors.success : AppColors.error,
    );
  }

  void _showMessage(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Color _directionColor(SyncDirection direction) {
    return switch (direction) {
      SyncDirection.uploadOnly => AppColors.success,
      SyncDirection.downloadOnly => AppColors.info,
      SyncDirection.twoWay => AppColors.sync,
      SyncDirection.mirrorLocalToRemote => AppColors.warning,
      SyncDirection.mirrorRemoteToLocal => AppColors.warning,
    };
  }

  String _directionLabel(SyncDirection value) {
    return switch (value) {
      SyncDirection.uploadOnly => 'Upload',
      SyncDirection.downloadOnly => 'Download',
      SyncDirection.twoWay => 'Two-Way',
      SyncDirection.mirrorLocalToRemote => 'Mirror Up',
      SyncDirection.mirrorRemoteToLocal => 'Mirror Down',
    };
  }

  String _conflictLabel(SyncConflictRule value) {
    return switch (value) {
      SyncConflictRule.newerWins => 'Newest Wins',
      SyncConflictRule.localWins => 'Local Wins',
      SyncConflictRule.remoteWins => 'Remote Wins',
      SyncConflictRule.keepBoth => 'Keep Both',
      SyncConflictRule.skip => 'Skip Conflicts',
    };
  }

  String _deleteLabel(SyncDeleteRule value) {
    return switch (value) {
      SyncDeleteRule.keepDeletedFiles => 'Keep Deletes',
      SyncDeleteRule.deleteRemoteWhenLocalDeleted => 'Delete Remote',
      SyncDeleteRule.deleteLocalWhenRemoteDeleted => 'Delete Local',
      SyncDeleteRule.deleteBothWays => 'Two-Way Deletes',
    };
  }

  String _triggerLabel(SyncTriggerRule value) {
    return switch (value) {
      SyncTriggerRule.manualOnly => 'Manual',
      SyncTriggerRule.onHomeWifi => 'Home Wi-Fi',
      SyncTriggerRule.hourly => 'Hourly',
      SyncTriggerRule.daily => 'Daily',
    };
  }

  Color _statusColor(SyncRuleStatus status) {
    return switch (status) {
      SyncRuleStatus.idle => AppColors.textHint,
      SyncRuleStatus.running => AppColors.info,
      SyncRuleStatus.success => AppColors.success,
      SyncRuleStatus.failed => AppColors.error,
    };
  }

  String _statusLabel(SyncRuleStatus status) {
    return switch (status) {
      SyncRuleStatus.idle => 'Idle',
      SyncRuleStatus.running => 'Running',
      SyncRuleStatus.success => 'Success',
      SyncRuleStatus.failed => 'Failed',
    };
  }

  bool _needsDeletePreview(SyncRuleModel rule) {
    return rule.deleteRule != SyncDeleteRule.keepDeletedFiles ||
        rule.direction == SyncDirection.mirrorLocalToRemote ||
        rule.direction == SyncDirection.mirrorRemoteToLocal;
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

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

class _RuleBadge extends StatelessWidget {
  const _RuleBadge({required this.label, required this.color});

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
