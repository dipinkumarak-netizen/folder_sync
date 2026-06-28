import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../ftp/presentation/ftp_server_list_screen.dart';
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
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.paddingM),
        children: [
          const _HeaderSection(),

          const SizedBox(height: AppSizes.paddingL),

          const SystemStatusCard(),

          const SizedBox(height: AppSizes.paddingL),

          DashboardCard(
            icon: AppIcons.server,
            iconColor: Colors.blue,
            title: 'FTP Server',
            subtitle: 'Configure FTP connections',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FtpServerListScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: AppSizes.paddingM),

          DashboardCard(
            icon: AppIcons.backup,
            iconColor: Colors.green,
            title: 'Backup Jobs',
            subtitle: 'Create and manage backup jobs',
            onTap: () {},
          ),

          const SizedBox(height: AppSizes.paddingM),

          DashboardCard(
            icon: AppIcons.sync,
            iconColor: Colors.orange,
            title: 'Synchronization',
            subtitle: 'Mirror and two-way sync',
            onTap: () {},
          ),

          const SizedBox(height: AppSizes.paddingM),

          DashboardCard(
            icon: AppIcons.restore,
            iconColor: Colors.purple,
            title: 'Restore',
            subtitle: 'Restore files from backup',
            onTap: () {},
          ),

          const SizedBox(height: AppSizes.paddingM),

          DashboardCard(
            icon: AppIcons.history,
            iconColor: Colors.cyan,
            title: 'History',
            subtitle: 'Backup history and logs',
            onTap: () {},
          ),

          const SizedBox(height: AppSizes.paddingM),

          DashboardCard(
            icon: AppIcons.settings,
            iconColor: Colors.red,
            title: 'Settings',
            subtitle: 'Application settings',
            onTap: () {},
          ),

          const SizedBox(height: AppSizes.paddingXL),
        ],
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingL),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            AppIcons.backup,
            size: 60,
            color: Colors.lightBlueAccent,
          ),
          const SizedBox(height: AppSizes.paddingM),
          Text(
            AppStrings.appName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSizes.paddingS),
          Text(
            'Free • Open Source • Privacy First',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}