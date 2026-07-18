import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/ob_card.dart';
import '../../dashboard/presentation/home_screen.dart';
import '../providers/app_settings_provider.dart';
import '../providers/permission_readiness_provider.dart';

/// ===============================================================
/// OpenBackup
/// File : onboarding_readiness_screen.dart
/// Version : 1.0.0
/// Description : First-run storage and permission readiness flow.
/// ===============================================================

class OnboardingReadinessScreen extends ConsumerWidget {
  const OnboardingReadinessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readiness = ref.watch(permissionReadinessProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.paddingM),
          children: [
            const SizedBox(height: AppSizes.paddingM),
            const Icon(AppIcons.backup, size: 64, color: AppColors.primary),
            const SizedBox(height: AppSizes.paddingM),
            Text(
              AppStrings.appName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSizes.paddingS),
            Text(
              'Prepare storage, notifications, Wi-Fi checks, and scheduling before your first backup.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textHint),
            ),
            const SizedBox(height: AppSizes.paddingL),
            readiness.when(
              loading: () => const _LoadingReadinessCard(),
              error: (_, _) => _ReadinessErrorCard(
                onRetry: () =>
                    ref.read(permissionReadinessProvider.notifier).refresh(),
              ),
              data: (snapshot) => Column(
                children: [
                  _ReadinessProgressCard(snapshot: snapshot),
                  const SizedBox(height: AppSizes.paddingM),
                  ...snapshot.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.paddingM),
                      child: _OnboardingReadinessTile(item: item),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.paddingS),
            FilledButton.icon(
              onPressed: () => _completeOnboarding(context, ref),
              icon: const Icon(AppIcons.success),
              label: const Text('Continue'),
            ),
            const SizedBox(height: AppSizes.paddingS),
            TextButton(
              onPressed: () => _completeOnboarding(context, ref),
              child: const Text('Skip for now'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _completeOnboarding(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(appSettingsProvider);
    await ref
        .read(appSettingsProvider.notifier)
        .updateSettings(settings.copyWith(onboardingCompleted: true));

    if (!context.mounted) {
      return;
    }

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }
}

class _LoadingReadinessCard extends StatelessWidget {
  const _LoadingReadinessCard();

  @override
  Widget build(BuildContext context) {
    return const OBCard(
      child: Padding(
        padding: EdgeInsets.all(AppSizes.paddingM),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ReadinessErrorCard extends StatelessWidget {
  const _ReadinessErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return OBCard(
      child: Column(
        children: [
          const Icon(AppIcons.error, size: 44, color: AppColors.error),
          const SizedBox(height: AppSizes.paddingM),
          Text(
            'Could not read readiness state.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSizes.paddingM),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(AppIcons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _ReadinessProgressCard extends StatelessWidget {
  const _ReadinessProgressCard({required this.snapshot});

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
                  snapshot.allReady ? 'Ready to Start' : 'Review Recommended',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSizes.paddingXS),
                Text(
                  '${snapshot.readyCount}/${snapshot.items.length} checks ready',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textHint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingReadinessTile extends ConsumerWidget {
  const _OnboardingReadinessTile({required this.item});

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
