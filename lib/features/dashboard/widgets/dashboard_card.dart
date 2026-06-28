import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/widgets/ob_card.dart';

/// ===============================================================
/// OpenBackup
/// File : dashboard_card.dart
/// Version : 1.0.0
/// Layer : Feature / Dashboard / Widgets
/// Description : Reusable dashboard action card.
/// License : Apache 2.0
/// ===============================================================

class DashboardCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const DashboardCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OBCard(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: iconColor.withValues(alpha: 0.15),
            child: Icon(
              icon,
              color: iconColor,
              size: AppSizes.iconL,
            ),
          ),

          const SizedBox(width: AppSizes.paddingM),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),

                const SizedBox(height: AppSizes.paddingXS),

                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),

          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textHint,
          ),
        ],
      ),
    );
  }
}