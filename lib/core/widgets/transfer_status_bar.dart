import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_icons.dart';
import '../constants/app_sizes.dart';
import '../models/transfer_progress_snapshot.dart';
import 'ob_card.dart';

/// ===============================================================
/// OpenBackup
/// File : transfer_status_bar.dart
/// Version : 1.0.0
/// Description : Shared file transfer status bar with speed details.
/// ===============================================================

class TransferStatusBar extends StatelessWidget {
  const TransferStatusBar({super.key, required this.progress});

  final TransferProgressSnapshot progress;

  @override
  Widget build(BuildContext context) {
    final progressValue = progress.progress;

    return OBCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.info.withValues(alpha: 0.15),
                child: const Icon(AppIcons.sync, color: AppColors.info),
              ),
              const SizedBox(width: AppSizes.paddingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progress.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSizes.paddingXS),
                    Text(
                      progress.status,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _fileCountLabel(progress),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingM),
          LinearProgressIndicator(value: progressValue),
          const SizedBox(height: AppSizes.paddingS),
          Wrap(
            spacing: AppSizes.paddingS,
            runSpacing: AppSizes.paddingS,
            children: [
              _ProgressChip(
                label: _formatBytes(progress.processedBytes),
                color: AppColors.info,
              ),
              _ProgressChip(
                label:
                    '${_formatBytes(progress.averageBytesPerSecond.round())}/s LAN',
                color: AppColors.success,
              ),
              if (progress.currentFilePath.isNotEmpty)
                _ProgressChip(
                  label: progress.currentFilePath,
                  color: AppColors.textHint,
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _fileCountLabel(TransferProgressSnapshot progress) {
    if (progress.totalFiles <= 0) {
      return '${progress.processedFiles} file(s)';
    }

    return '${progress.processedFiles}/${progress.totalFiles}';
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

class _ProgressChip extends StatelessWidget {
  const _ProgressChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingS,
        vertical: AppSizes.paddingXS,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }
}
