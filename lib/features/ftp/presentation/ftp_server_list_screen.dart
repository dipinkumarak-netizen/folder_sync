import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../models/ftp_server_model.dart';
import '../providers/ftp_provider.dart';
import 'ftp_server_form_screen.dart';

/// ===============================================================
/// OpenBackup
/// File : ftp_server_list_screen.dart
/// Version : 1.1.0
/// Description : FTP Server List Screen
/// ===============================================================

class FtpServerListScreen extends ConsumerWidget {
  const FtpServerListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(ftpServerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("FTP Servers")),
      floatingActionButton: FloatingActionButton(
        tooltip: "Add FTP Server",
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FtpServerFormScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: servers.isEmpty
          ? const _EmptyServerList()
          : ListView.separated(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              itemCount: servers.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSizes.paddingM),
              itemBuilder: (context, index) {
                return _FtpServerTile(server: servers[index]);
              },
            ),
    );
  }
}

class _EmptyServerList extends StatelessWidget {
  const _EmptyServerList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSizes.paddingL),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: const [
              Icon(Icons.dns_rounded, size: 60, color: Colors.blue),
              SizedBox(height: 16),
              Text(
                "No FTP Servers",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 10),
              Text(
                "Press the + button to add your first FTP server.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FtpServerTile extends StatelessWidget {
  const _FtpServerTile({required this.server});

  final FtpServerModel server;

  @override
  Widget build(BuildContext context) {
    final username = server.isAnonymous ? 'Anonymous' : server.username;

    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: const Icon(Icons.dns_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: AppSizes.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  server.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSizes.paddingXS),
                Text(
                  '${server.host}:${server.port} - $username',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.textHint),
                ),
                const SizedBox(height: AppSizes.paddingXS),
                Text(
                  server.remotePath,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
