import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/widgets/ob_card.dart';
import '../../ftp/models/ftp_server_model.dart';
import '../../ftp/presentation/ftp_server_list_screen.dart';
import '../../ftp/providers/ftp_provider.dart';
import '../models/backup_job_model.dart';
import '../providers/backup_permission_provider.dart';
import '../providers/backup_provider.dart';
import 'backup_job_form_screen.dart';

/// ===============================================================
/// OpenBackup
/// File : backup_job_list_screen.dart
/// Version : 1.0.0
/// Description : Backup job list and manual run screen.
/// ===============================================================

class BackupJobListScreen extends ConsumerWidget {
  const BackupJobListScreen({super.key});

  void _openForm(BuildContext context, [BackupJobModel? job]) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BackupJobFormScreen(job: job)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(backupJobLoadProvider);
    ref.watch(ftpServerLoadProvider);
    final jobs = ref.watch(backupJobProvider);
    final ftpServers = ref.watch(ftpServerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Backup Jobs')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add Backup Job',
        onPressed: () => _openForm(context),
        child: const Icon(AppIcons.add),
      ),
      body: jobs.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              children: [
                const _ForegroundReadinessCard(),
                const SizedBox(height: AppSizes.paddingM),
                _EmptyBackupJobs(hasFtpServers: ftpServers.isNotEmpty),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              itemCount: jobs.length + 1,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSizes.paddingM),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const _ForegroundReadinessCard();
                }

                final job = jobs[index - 1];
                return _BackupJobTile(
                  job: job,
                  ftpServer: _findServer(ftpServers, job.ftpServerId),
                  onEdit: () => _openForm(context, job),
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

class _EmptyBackupJobs extends StatelessWidget {
  const _EmptyBackupJobs({required this.hasFtpServers});

  final bool hasFtpServers;

  @override
  Widget build(BuildContext context) {
    return OBCard(
      child: Column(
        children: [
          const Icon(AppIcons.backup, size: 60, color: Colors.green),
          const SizedBox(height: AppSizes.paddingM),
          Text(
            'No Backup Jobs',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSizes.paddingS),
          Text(
            hasFtpServers
                ? 'Press the + button to back up a local folder to FTP.'
                : 'Add an FTP server first, then create a backup job.',
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

class _ForegroundReadinessCard extends ConsumerWidget {
  const _ForegroundReadinessCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionState = ref.watch(backupPermissionProvider);

    return permissionState.when(
      loading: () => const OBCard(
        child: Row(
          children: [
            Icon(AppIcons.info, color: AppColors.info),
            SizedBox(width: AppSizes.paddingM),
            Expanded(child: Text('Checking backup permissions...')),
          ],
        ),
      ),
      error: (_, _) => const _PermissionContent(
        icon: AppIcons.warning,
        iconColor: AppColors.warning,
        title: 'Permission Check Unavailable',
        message: 'Backup can run now, but notification readiness is unknown.',
      ),
      data: (state) {
        if (state.canShowForegroundProgress) {
          return const _PermissionContent(
            icon: AppIcons.success,
            iconColor: AppColors.success,
            title: 'Foreground Backup Ready',
            message: 'Backup progress notifications are enabled.',
          );
        }

        return _PermissionContent(
          icon: AppIcons.warning,
          iconColor: AppColors.warning,
          title: 'Enable Backup Notifications',
          message:
              'Android requires a visible notification for long-running backup work.',
          actionLabel: state.notificationPermanentlyDenied
              ? 'Open Settings'
              : 'Allow Notifications',
          onAction: state.notificationPermanentlyDenied
              ? openAppSettings
              : () => ref
                    .read(backupPermissionProvider.notifier)
                    .requestNotificationPermission(),
        );
      },
    );
  }
}

class _PermissionContent extends StatelessWidget {
  const _PermissionContent({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return OBCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: iconColor.withValues(alpha: 0.15),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: AppSizes.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSizes.paddingXS),
                Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.textHint),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: AppSizes.paddingS),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _BackupJobTile extends ConsumerWidget {
  const _BackupJobTile({
    required this.job,
    required this.ftpServer,
    required this.onEdit,
  });

  final BackupJobModel job;
  final FtpServerModel? ftpServer;
  final VoidCallback onEdit;

  Future<void> _runBackup(BuildContext context, WidgetRef ref) async {
    final server = ftpServer;
    if (server == null) {
      _showMessage(
        context,
        'The selected FTP server is not available.',
        AppColors.error,
      );
      return;
    }

    if (!job.enabled) {
      _showMessage(
        context,
        'Enable this job before running it.',
        AppColors.warning,
      );
      return;
    }

    final result = await ref
        .read(backupJobProvider.notifier)
        .runJob(job: job, ftpServer: server);

    if (!context.mounted) {
      return;
    }

    _showMessage(
      context,
      result.message,
      result.success ? AppColors.success : AppColors.error,
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Backup Job'),
          content: Text('Delete "${job.name}" from your backup jobs?'),
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
      await ref.read(backupJobProvider.notifier).deleteJob(job.id);
    }
  }

  void _showMessage(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRunning = job.status == BackupJobStatus.running;
    final statusColor = _statusColor(job.status);

    return OBCard(
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: statusColor.withValues(alpha: 0.15),
                child: Icon(AppIcons.backup, color: statusColor),
              ),
              const SizedBox(width: AppSizes.paddingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.name,
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
                value: job.enabled,
                onChanged: isRunning
                    ? null
                    : (value) {
                        ref
                            .read(backupJobProvider.notifier)
                            .toggleJob(job.id, value);
                      },
              ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingM),
          _InfoRow(icon: AppIcons.folder, text: job.localFolderPath),
          const SizedBox(height: AppSizes.paddingS),
          _InfoRow(icon: AppIcons.upload, text: job.remoteFolderPath),
          const SizedBox(height: AppSizes.paddingM),
          Wrap(
            spacing: AppSizes.paddingS,
            runSpacing: AppSizes.paddingS,
            children: [
              _StatusChip(label: _statusLabel(job.status), color: statusColor),
              _StatusChip(
                label: _scheduleLabel(job.scheduleRule),
                color: AppColors.schedule,
              ),
              _StatusChip(
                label: '${job.totalFilesBackedUp} files',
                color: AppColors.info,
              ),
              _StatusChip(
                label: _formatBytes(job.totalBytesBackedUp),
                color: AppColors.success,
              ),
              if (job.runOnWifiOnly)
                const _StatusChip(
                  label: 'Wi-Fi Only',
                  color: AppColors.success,
                ),
              if (job.homeWifiName.isNotEmpty)
                _StatusChip(label: job.homeWifiName, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: AppSizes.paddingM),
          Text(_lastRunText(job), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSizes.paddingS),
          Text(job.lastMessage, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSizes.paddingM),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: isRunning ? null : () => _runBackup(context, ref),
                  icon: isRunning
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(AppIcons.upload),
                  label: Text(isRunning ? 'Running' : 'Run Now'),
                ),
              ),
              const SizedBox(width: AppSizes.paddingS),
              IconButton(
                tooltip: 'Edit Backup Job',
                icon: const Icon(AppIcons.edit),
                onPressed: isRunning ? null : onEdit,
              ),
              IconButton(
                tooltip: 'Delete Backup Job',
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

  Color _statusColor(BackupJobStatus status) {
    return switch (status) {
      BackupJobStatus.idle => AppColors.textHint,
      BackupJobStatus.running => AppColors.info,
      BackupJobStatus.success => AppColors.success,
      BackupJobStatus.failed => AppColors.error,
    };
  }

  String _statusLabel(BackupJobStatus status) {
    return switch (status) {
      BackupJobStatus.idle => 'Idle',
      BackupJobStatus.running => 'Running',
      BackupJobStatus.success => 'Success',
      BackupJobStatus.failed => 'Failed',
    };
  }

  String _scheduleLabel(BackupScheduleRule scheduleRule) {
    return switch (scheduleRule) {
      BackupScheduleRule.manualOnly => 'Manual',
      BackupScheduleRule.hourly => 'Hourly',
      BackupScheduleRule.daily => 'Daily',
    };
  }

  String _lastRunText(BackupJobModel job) {
    final lastRunAt = job.lastRunAt;
    if (lastRunAt == null) {
      return 'Last run: Never';
    }

    return 'Last run: ${lastRunAt.year}-${_twoDigits(lastRunAt.month)}-'
        '${_twoDigits(lastRunAt.day)} ${_twoDigits(lastRunAt.hour)}:'
        '${_twoDigits(lastRunAt.minute)}';
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

    final gb = mb / 1024;
    return '${gb.toStringAsFixed(1)} GB';
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

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
