import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/widgets/ob_card.dart';

/// ===============================================================
/// OpenBackup
/// File : system_status_card.dart
/// Version : 1.0.0
/// Description : Dashboard system status widget.
/// ===============================================================

class SystemStatusCard extends StatelessWidget {
  const SystemStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return OBCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Status',
            style: Theme.of(context).textTheme.titleLarge,
          ),

          const SizedBox(height: AppSizes.paddingM),

          const Row(
            children: [
              Expanded(
                child: _StatusItem(
                  icon: AppIcons.server,
                  color: Colors.green,
                  title: 'FTP',
                  value: 'Disconnected',
                ),
              ),
              Expanded(
                child: _StatusItem(
                  icon: AppIcons.wifi,
                  color: Colors.blue,
                  title: 'Network',
                  value: 'Connected',
                ),
              ),
            ],
          ),

          SizedBox(height: AppSizes.paddingM),

          const Row(
            children: [
              Expanded(
                child: _StatusItem(
                  icon: AppIcons.storage,
                  color: Colors.orange,
                  title: 'Storage',
                  value: '--',
                ),
              ),
              Expanded(
                child: _StatusItem(
                  icon: AppIcons.battery,
                  color: Colors.lightGreen,
                  title: 'Battery',
                  value: '--%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;

  const _StatusItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(
            icon,
            color: color,
          ),
        ),

        const SizedBox(width: AppSizes.paddingS),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textHint,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}