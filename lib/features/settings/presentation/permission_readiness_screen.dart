import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/widgets/ob_card.dart';
import '../providers/permission_readiness_provider.dart';

/// ===============================================================
/// OpenBackup
/// File : permission_readiness_screen.dart
/// Version : 1.0.0
/// Description : Storage and Android permission readiness checklist.
/// ===============================================================

class PermissionReadinessScreen extends ConsumerWidget {
  const PermissionReadinessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readiness = ref.watch(permissionReadinessProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Readiness Check'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(AppIcons.refresh),
            onPressed: () =>
                ref.read(permissionReadinessProvider.notifier).refresh(),
          ),
        ],
      ),
      body: readiness.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ListView(
          padding: const EdgeInsets.all(AppSizes.paddingM),
          children: [
            OBCard(
              child: Column(
                children: [
                  const Icon(AppIcons.error, size: 48, color: AppColors.error),
                  const SizedBox(height: AppSizes.paddingM),
                  Text(
                    'Could not read readiness state.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSizes.paddingM),
                  FilledButton.icon(
                    onPressed: () => ref
                        .read(permissionReadinessProvider.notifier)
                        .refresh(),
                    icon: const Icon(AppIcons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ],
        ),
        data: (snapshot) => ListView(
          padding: const EdgeInsets.all(AppSizes.paddingM),
          children: [
            _ReadinessSummary(snapshot: snapshot),
            const SizedBox(height: AppSizes.paddingM),
            ...snapshot.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.paddingM),
                child: _ReadinessTile(item: item),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadinessSummary extends StatelessWidget {
  const _ReadinessSummary({required this.snapshot});

  final PermissionReadinessSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final color = snapshot.allReady ? AppColors.success : AppColors.warning;

    return OBCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(
              snapshot.allReady ? AppIcons.success : AppIcons.warning,
              color: color,
            ),
          ),
          const SizedBox(width: AppSizes.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snapshot.allReady ? 'Ready' : 'Needs Attention',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSizes.paddingXS),
                Text(
                  '${snapshot.readyCount}/${snapshot.items.length} checks ready',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.textHint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadinessTile extends ConsumerWidget {
  const _ReadinessTile({required this.item});

  final PermissionReadinessItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _statusColor(item.status);

    return OBCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_statusIcon(item.status), color: color),
          const SizedBox(width: AppSizes.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSizes.paddingXS),
                Text(
                  item.message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textHint),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.paddingM),
          TextButton(
            onPressed: () => _handleAction(ref, item),
            child: Text(item.actionLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(
    WidgetRef ref,
    PermissionReadinessItem item,
  ) async {
    final notifier = ref.read(permissionReadinessProvider.notifier);
    switch (item.id) {
      case 'notifications':
        if (item.status == ReadinessStatus.blocked) {
          await openAppSettings();
          await notifier.refresh();
          return;
        }
        await notifier.requestNotification();
        return;
      case 'wifi_name':
        if (item.status == ReadinessStatus.blocked) {
          await openAppSettings();
          await notifier.refresh();
          return;
        }
        await notifier.requestWifiNameAccess();
        return;
      case 'battery':
        await notifier.requestBatteryOptimizationExemption();
        return;
      case 'app_storage':
        await notifier.refresh();
        return;
      case 'folder_picker':
        await openAppSettings();
        await notifier.refresh();
        return;
    }
  }

  Color _statusColor(ReadinessStatus status) {
    return switch (status) {
      ReadinessStatus.ready => AppColors.success,
      ReadinessStatus.warning => AppColors.warning,
      ReadinessStatus.blocked => AppColors.error,
      ReadinessStatus.unknown => AppColors.info,
    };
  }

  IconData _statusIcon(ReadinessStatus status) {
    return switch (status) {
      ReadinessStatus.ready => AppIcons.success,
      ReadinessStatus.warning => AppIcons.warning,
      ReadinessStatus.blocked => AppIcons.error,
      ReadinessStatus.unknown => AppIcons.info,
    };
  }
}
