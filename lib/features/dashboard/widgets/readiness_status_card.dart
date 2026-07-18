import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/widgets/ob_card.dart';
import '../../settings/presentation/permission_readiness_screen.dart';
import '../../settings/providers/permission_readiness_provider.dart';

/// ===============================================================
/// OpenBackup
/// File : readiness_status_card.dart
/// Version : 1.0.0
/// Description : Dashboard readiness summary for storage and permissions.
/// ===============================================================

class ReadinessStatusCard extends ConsumerWidget {
  const ReadinessStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readiness = ref.watch(permissionReadinessProvider);

    return OBCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PermissionReadinessScreen()),
        );
      },
      child: readiness.when(
        loading: () => const _ReadinessCardContent(
          icon: AppIcons.info,
          color: AppColors.info,
          title: 'Readiness',
          message: 'Checking storage and permissions',
          trailing: 'Open',
        ),
        error: (_, _) => const _ReadinessCardContent(
          icon: AppIcons.warning,
          color: AppColors.warning,
          title: 'Readiness',
          message: 'Could not check storage and permissions',
          trailing: 'Review',
        ),
        data: (snapshot) {
          final blockingCount = snapshot.items
              .where((item) => item.status == ReadinessStatus.blocked)
              .length;
          final warningCount = snapshot.items
              .where((item) => item.status == ReadinessStatus.warning)
              .length;
          final issueCount = blockingCount + warningCount;
          final allReady = issueCount == 0;

          return _ReadinessCardContent(
            icon: allReady ? AppIcons.success : AppIcons.warning,
            color: allReady ? AppColors.success : AppColors.warning,
            title: 'Readiness',
            message: allReady
                ? 'Storage and permissions are ready'
                : '$issueCount item(s) need attention',
            trailing: allReady
                ? '${snapshot.readyCount}/${snapshot.items.length}'
                : 'Review',
          );
        },
      ),
    );
  }
}

class _ReadinessCardContent extends StatelessWidget {
  const _ReadinessCardContent({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.trailing,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: AppSizes.paddingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
        const SizedBox(width: AppSizes.paddingM),
        Text(
          trailing,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
        ),
        const SizedBox(width: AppSizes.paddingXS),
        const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
      ],
    );
  }
}
