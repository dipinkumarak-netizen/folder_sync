import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/widgets/ob_card.dart';
import '../providers/system_status_provider.dart';

/// ===============================================================
/// OpenBackup
/// File : system_status_card.dart
/// Version : 1.1.0
/// Description : Dashboard system status widget.
/// ===============================================================

class SystemStatusCard extends ConsumerWidget {
  const SystemStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(systemStatusProvider);

    return OBCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'System Status',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Refresh System Status',
                icon: const Icon(AppIcons.refresh),
                onPressed: () => ref.invalidate(systemStatusProvider),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingM),
          status.when(
            loading: () => const _StatusGrid(
              items: [
                _StatusItemData(
                  icon: AppIcons.server,
                  color: AppColors.info,
                  title: 'FTP',
                  value: 'Checking',
                ),
                _StatusItemData(
                  icon: AppIcons.wifi,
                  color: AppColors.info,
                  title: 'Network',
                  value: 'Checking',
                ),
                _StatusItemData(
                  icon: AppIcons.storage,
                  color: AppColors.info,
                  title: 'Storage',
                  value: 'Checking',
                ),
                _StatusItemData(
                  icon: AppIcons.battery,
                  color: AppColors.info,
                  title: 'Battery',
                  value: 'Checking',
                ),
              ],
            ),
            error: (_, _) => const _StatusGrid(
              items: [
                _StatusItemData(
                  icon: AppIcons.server,
                  color: AppColors.warning,
                  title: 'FTP',
                  value: 'Unavailable',
                ),
                _StatusItemData(
                  icon: AppIcons.wifi,
                  color: AppColors.warning,
                  title: 'Network',
                  value: 'Unavailable',
                ),
                _StatusItemData(
                  icon: AppIcons.storage,
                  color: AppColors.warning,
                  title: 'Storage',
                  value: 'Unavailable',
                ),
                _StatusItemData(
                  icon: AppIcons.battery,
                  color: AppColors.warning,
                  title: 'Battery',
                  value: 'Unavailable',
                ),
              ],
            ),
            data: (snapshot) => _StatusGrid(
              items: [
                _StatusItemData(
                  icon: AppIcons.server,
                  color: snapshot.configuredFtpServers > 0
                      ? AppColors.success
                      : AppColors.warning,
                  title: 'FTP',
                  value: '${snapshot.configuredFtpServers} server(s)',
                ),
                _StatusItemData(
                  icon: _networkIcon(snapshot.connectivity),
                  color: snapshot.isOnline
                      ? AppColors.success
                      : AppColors.error,
                  title: 'Network',
                  value: _networkLabel(
                    snapshot.connectivity,
                    snapshot.wifiSsid,
                  ),
                ),
                _StatusItemData(
                  icon: AppIcons.storage,
                  color: snapshot.availableStorageBytes == null
                      ? AppColors.warning
                      : AppColors.info,
                  title: 'Storage',
                  value: _storageLabel(snapshot.availableStorageBytes),
                ),
                _StatusItemData(
                  icon: _batteryIcon(snapshot.batteryState),
                  color: _batteryColor(snapshot.batteryLevel),
                  title: 'Battery',
                  value: _batteryLabel(
                    snapshot.batteryLevel,
                    snapshot.batteryState,
                  ),
                ),
                _StatusItemData(
                  icon: AppIcons.backup,
                  color: snapshot.configuredBackupJobs > 0
                      ? AppColors.success
                      : AppColors.warning,
                  title: 'Jobs',
                  value: '${snapshot.configuredBackupJobs} job(s)',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _networkIcon(List<ConnectivityResult> connectivity) {
    if (connectivity.contains(ConnectivityResult.wifi)) {
      return AppIcons.wifi;
    }

    if (connectivity.contains(ConnectivityResult.ethernet)) {
      return AppIcons.ethernet;
    }

    return AppIcons.network;
  }

  static String _networkLabel(
    List<ConnectivityResult> connectivity,
    String? wifiSsid,
  ) {
    if (connectivity.any((result) => result != ConnectivityResult.none)) {
      if (connectivity.contains(ConnectivityResult.wifi)) {
        return wifiSsid ?? 'Wi-Fi';
      }

      if (connectivity.contains(ConnectivityResult.mobile)) {
        return 'Mobile';
      }

      if (connectivity.contains(ConnectivityResult.ethernet)) {
        return 'Ethernet';
      }

      return 'Connected';
    }

    return 'Offline';
  }

  static IconData _batteryIcon(BatteryState? state) {
    if (state == BatteryState.charging || state == BatteryState.full) {
      return AppIcons.charging;
    }

    return AppIcons.battery;
  }

  static Color _batteryColor(int? level) {
    if (level == null) {
      return AppColors.warning;
    }

    if (level <= 20) {
      return AppColors.error;
    }

    return AppColors.success;
  }

  static String _batteryLabel(int? level, BatteryState? state) {
    if (level == null) {
      return 'Unavailable';
    }

    final suffix = switch (state) {
      BatteryState.charging => ' charging',
      BatteryState.full => ' full',
      _ => '',
    };

    return '$level%$suffix';
  }

  static String _storageLabel(int? bytes) {
    if (bytes == null) {
      return 'Unavailable';
    }

    final gigabytes = bytes / (1024 * 1024 * 1024);
    if (gigabytes >= 1) {
      return '${gigabytes.toStringAsFixed(1)} GB free';
    }

    final megabytes = bytes / (1024 * 1024);
    return '${megabytes.toStringAsFixed(0)} MB free';
  }
}

class _StatusGrid extends StatelessWidget {
  const _StatusGrid({required this.items});

  final List<_StatusItemData> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 520 ? 3 : 2;

        return Wrap(
          spacing: AppSizes.paddingM,
          runSpacing: AppSizes.paddingM,
          children: items.map((item) {
            final width =
                (constraints.maxWidth - (AppSizes.paddingM * (columns - 1))) /
                columns;
            return SizedBox(
              width: width,
              child: _StatusItem(item: item),
            );
          }).toList(),
        );
      },
    );
  }
}

class _StatusItemData {
  final IconData icon;
  final Color color;
  final String title;
  final String value;

  const _StatusItemData({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
  });
}

class _StatusItem extends StatelessWidget {
  const _StatusItem({required this.item});

  final _StatusItemData item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: item.color.withValues(alpha: 0.15),
          child: Icon(item.icon, color: item.color),
        ),
        const SizedBox(width: AppSizes.paddingS),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: AppColors.textHint),
              ),
              const SizedBox(height: 2),
              Text(
                item.value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
