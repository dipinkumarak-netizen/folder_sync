import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../backup/presentation/backup_job_list_screen.dart';
import '../../history/presentation/history_screen.dart';
import '../../restore/presentation/restore_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../sync/presentation/sync_rule_list_screen.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/system_status_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        title: Text(AppStrings.appName),
        leading: IconButton(
          icon: const Icon(AppIcons.settings),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.paddingM),
        children: [
          const SystemStatusCard(),

          const SizedBox(height: AppSizes.paddingL),

          DashboardCard(
            icon: AppIcons.backup,
            iconColor: Colors.green,
            title: 'Backup Jobs',
            subtitle: 'Create and manage backup jobs',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BackupJobListScreen()),
              );
            },
          ),

          const SizedBox(height: AppSizes.paddingM),

          DashboardCard(
            icon: AppIcons.sync,
            iconColor: Colors.orange,
            title: 'Synchronization',
            subtitle: 'Mirror and two-way sync',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SyncRuleListScreen()),
              );
            },
          ),

          const SizedBox(height: AppSizes.paddingM),

          DashboardCard(
            icon: AppIcons.restore,
            iconColor: Colors.purple,
            title: 'Restore',
            subtitle: 'Restore files from backup',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RestoreScreen()),
              );
            },
          ),

          const SizedBox(height: AppSizes.paddingM),

          DashboardCard(
            icon: AppIcons.history,
            iconColor: Colors.cyan,
            title: 'History',
            subtitle: 'Backup history and logs',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
            },
          ),

          const SizedBox(height: AppSizes.paddingXL),
        ],
      ),
    );
  }
}
