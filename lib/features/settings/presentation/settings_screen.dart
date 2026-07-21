import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/ob_card.dart';
import '../../history/providers/history_provider.dart';
import '../../scheduler/providers/scheduler_provider.dart';
import '../models/app_settings_model.dart';
import '../providers/app_settings_provider.dart';
import 'permission_readiness_screen.dart';
import '../../ftp/presentation/ftp_server_list_screen.dart';

/// ===============================================================
/// OpenBackup
/// File : settings_screen.dart
/// Version : 1.0.0
/// Description : Application settings screen.
/// ===============================================================

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appSettingsLoadProvider);
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.paddingM),
        children: [
          _SettingsSection(
            icon: AppIcons.schedule,
            iconColor: AppColors.schedule,
            title: 'Scheduling',
            children: [
              _SwitchSettingTile(
                title: 'Automatic Scheduling',
                subtitle: 'Runs hourly, daily, and home Wi-Fi jobs.',
                value: settings.automaticSchedulingEnabled,
                onChanged: (value) => _updateSettings(
                  ref,
                  settings.copyWith(automaticSchedulingEnabled: value),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingM),
          _SettingsSection(
            icon: AppIcons.wifi,
            iconColor: AppColors.success,
            title: 'Network Defaults',
            children: [
              _SwitchSettingTile(
                title: 'Backup Wi-Fi Only',
                subtitle: 'New backup jobs use Wi-Fi only by default.',
                value: settings.defaultBackupWifiOnly,
                onChanged: (value) => _updateSettings(
                  ref,
                  settings.copyWith(defaultBackupWifiOnly: value),
                ),
              ),
              const Divider(height: AppSizes.paddingL),
              _SwitchSettingTile(
                title: 'Sync Wi-Fi Only',
                subtitle: 'New sync rules use Wi-Fi only by default.',
                value: settings.defaultSyncWifiOnly,
                onChanged: (value) => _updateSettings(
                  ref,
                  settings.copyWith(defaultSyncWifiOnly: value),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingM),
          _ServerSection(),
          const SizedBox(height: AppSizes.paddingM),
          _PermissionsSection(settings: settings),
          const SizedBox(height: AppSizes.paddingM),
          _DataSection(),
          const SizedBox(height: AppSizes.paddingM),
          const _AppInfoSection(),
          const SizedBox(height: AppSizes.paddingXL),
        ],
      ),
    );
  }

  Future<void> _updateSettings(WidgetRef ref, AppSettingsModel settings) async {
    await ref.read(appSettingsProvider.notifier).updateSettings(settings);
    await ref.read(schedulerProvider).refreshBackgroundSchedule();
  }
}

class _ServerSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      icon: AppIcons.server,
      iconColor: Colors.blue,
      title: 'FTP Connections',
      children: [
        _ActionSettingTile(
          title: 'FTP Servers',
          subtitle: 'Configure and manage your FTP server connections.',
          actionLabel: 'Manage',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FtpServerListScreen()),
            );
          },
        ),
      ],
    );
  }
}

class _PermissionsSection extends ConsumerWidget {
  const _PermissionsSection({required this.settings});

  final AppSettingsModel settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SettingsSection(
      icon: AppIcons.info,
      iconColor: AppColors.info,
      title: 'Permissions',
      children: [
        _SwitchSettingTile(
          title: 'Foreground Notifications',
          subtitle: 'Shows progress while backup and sync jobs run.',
          value: settings.showForegroundNotifications,
          onChanged: (value) async {
            await ref
                .read(appSettingsProvider.notifier)
                .updateSettings(
                  settings.copyWith(showForegroundNotifications: value),
                );
            await ref.read(schedulerProvider).refreshBackgroundSchedule();
            if (value) {
              await Permission.notification.request();
            }
          },
        ),
        const Divider(height: AppSizes.paddingL),
        _ActionSettingTile(
          title: 'Permission Check',
          subtitle:
              'Review storage, notification, Wi-Fi, and battery readiness.',
          actionLabel: 'Open',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PermissionReadinessScreen(),
              ),
            );
          },
        ),
        const Divider(height: AppSizes.paddingL),
        _ActionSettingTile(
          title: 'Wi-Fi Name Access',
          subtitle: 'Required for home Wi-Fi backup and sync rules.',
          actionLabel: 'Allow',
          onPressed: () async {
            await Permission.nearbyWifiDevices.request();
            await Permission.locationWhenInUse.request();
          },
        ),
        const Divider(height: AppSizes.paddingL),
        _ActionSettingTile(
          title: 'Android App Settings',
          subtitle: 'Open system permissions and battery settings.',
          actionLabel: 'Open',
          onPressed: openAppSettings,
        ),
      ],
    );
  }
}

class _DataSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SettingsSection(
      icon: AppIcons.storage,
      iconColor: AppColors.warning,
      title: 'Data',
      children: [
        _ActionSettingTile(
          title: 'Clear History',
          subtitle: 'Removes local backup and sync history entries.',
          actionLabel: 'Clear',
          actionColor: AppColors.error,
          onPressed: () => _confirmClearHistory(context, ref),
        ),
      ],
    );
  }

  Future<void> _confirmClearHistory(BuildContext context, WidgetRef ref) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear History'),
          content: const Text('Delete all backup and sync history entries?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (shouldClear != true || !context.mounted) {
      return;
    }

    await ref.read(historyProvider.notifier).clearEntries();
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('History cleared.'),
        backgroundColor: AppColors.success,
      ),
    );
  }
}

class _AppInfoSection extends StatelessWidget {
  const _AppInfoSection();

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      icon: AppIcons.settings,
      iconColor: AppColors.settings,
      title: 'App',
      children: const [
        _InfoSettingTile(title: 'Name', value: AppStrings.appName),
        Divider(height: AppSizes.paddingL),
        _InfoSettingTile(title: 'Version', value: AppStrings.appVersion),
        Divider(height: AppSizes.paddingL),
        _InfoSettingTile(title: 'Storage', value: 'Local device only'),
        Divider(height: AppSizes.paddingL),
        _InfoSettingTile(title: 'Creater', value: 'Dipin A K'),
        _InfoSettingTile(title: ' ', value: 'Edumba'),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return OBCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: iconColor.withValues(alpha: 0.15),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: AppSizes.paddingM),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingM),
          ...children,
        ],
      ),
    );
  }
}

class _SwitchSettingTile extends StatelessWidget {
  const _SwitchSettingTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _ActionSettingTile extends StatelessWidget {
  const _ActionSettingTile({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onPressed,
    this.actionColor,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onPressed;
  final Color? actionColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSizes.paddingXS),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textHint),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSizes.paddingM),
        TextButton(
          onPressed: onPressed,
          child: Text(
            actionLabel,
            style: actionColor == null ? null : TextStyle(color: actionColor),
          ),
        ),
      ],
    );
  }
}

class _InfoSettingTile extends StatelessWidget {
  const _InfoSettingTile({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        const SizedBox(width: AppSizes.paddingM),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textHint),
          ),
        ),
      ],
    );
  }
}
