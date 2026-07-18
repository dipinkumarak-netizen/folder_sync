import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/widgets/ob_card.dart';
import '../../ftp/models/ftp_server_model.dart';
import '../../ftp/presentation/ftp_server_list_screen.dart';
import '../../ftp/providers/ftp_provider.dart';
import '../providers/restore_provider.dart';

/// ===============================================================
/// OpenBackup
/// File : restore_screen.dart
/// Version : 1.0.0
/// Description : Manual FTP restore screen with preview support.
/// ===============================================================

class RestoreScreen extends ConsumerStatefulWidget {
  const RestoreScreen({super.key});

  @override
  ConsumerState<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends ConsumerState<RestoreScreen> {
  final _formKey = GlobalKey<FormState>();
  final _remoteFolderController = TextEditingController(text: '/');
  final _localFolderController = TextEditingController();

  String? _selectedFtpServerId;

  @override
  void dispose() {
    _remoteFolderController.dispose();
    _localFolderController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: AppColors.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
    );
  }

  Future<void> _pickDestinationFolder() async {
    final folderPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Restore Destination',
    );

    if (folderPath == null || !mounted) {
      return;
    }

    _localFolderController.text = folderPath;
  }

  Future<void> _previewFiles(List<FtpServerModel> ftpServers) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final ftpServer = _selectedFtpServer(ftpServers);
    if (ftpServer == null) {
      return;
    }

    final result = await ref
        .read(restoreProvider.notifier)
        .previewFiles(
          ftpServer: ftpServer,
          remoteFolderPath: _remoteFolderController.text.trim(),
        );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _restoreNow(List<FtpServerModel> ftpServers) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final ftpServer = _selectedFtpServer(ftpServers);
    if (ftpServer == null) {
      return;
    }

    final shouldRestore = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Start Restore'),
          content: const Text(
            'Files that already exist in the destination folder will be skipped.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );

    if (shouldRestore != true || !mounted) {
      return;
    }

    final result = await ref
        .read(restoreProvider.notifier)
        .runRestore(
          ftpServer: ftpServer,
          remoteFolderPath: _remoteFolderController.text.trim(),
          localFolderPath: _localFolderController.text.trim(),
        );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  FtpServerModel? _selectedFtpServer(List<FtpServerModel> ftpServers) {
    for (final server in ftpServers) {
      if (server.id == _selectedFtpServerId) {
        return server;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(ftpServerLoadProvider);
    final ftpServers = ref.watch(ftpServerProvider);
    final restoreState = ref.watch(restoreProvider);
    final isBusy =
        restoreState.status == RestoreStatus.previewing ||
        restoreState.status == RestoreStatus.running;

    if (_selectedFtpServerId == null && ftpServers.length == 1) {
      _selectedFtpServerId = ftpServers.first.id;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Restore')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.paddingM),
            children: [
              _RestoreOverview(state: restoreState),
              const SizedBox(height: AppSizes.paddingM),
              _RestoreFormCard(
                ftpServers: ftpServers,
                selectedFtpServerId: _selectedFtpServerId,
                remoteFolderController: _remoteFolderController,
                localFolderController: _localFolderController,
                inputDecoration: _inputDecoration,
                onFtpChanged: isBusy
                    ? null
                    : (value) {
                        setState(() {
                          _selectedFtpServerId = value;
                        });
                      },
                onPickDestination: isBusy ? null : _pickDestinationFolder,
              ),
              const SizedBox(height: AppSizes.paddingM),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isBusy
                          ? null
                          : () => _previewFiles(ftpServers),
                      icon: const Icon(AppIcons.search),
                      label: const Text('Preview Files'),
                    ),
                  ),
                  const SizedBox(width: AppSizes.paddingM),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isBusy ? null : () => _restoreNow(ftpServers),
                      icon: const Icon(AppIcons.download),
                      label: const Text('Restore Now'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.paddingM),
              if (ftpServers.isEmpty) const _MissingFtpServerCard(),
              if (ftpServers.isEmpty) const SizedBox(height: AppSizes.paddingM),
              _PreviewList(state: restoreState),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestoreOverview extends StatelessWidget {
  const _RestoreOverview({required this.state});

  final RestoreState state;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (state.status) {
      RestoreStatus.success => AppColors.success,
      RestoreStatus.failed => AppColors.error,
      RestoreStatus.running || RestoreStatus.previewing => AppColors.warning,
      RestoreStatus.ready => AppColors.info,
      RestoreStatus.idle => AppColors.restore,
    };

    return OBCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: statusColor.withValues(alpha: 0.15),
            child: Icon(AppIcons.restore, color: statusColor),
          ),
          const SizedBox(width: AppSizes.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Restore Backup',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSizes.paddingXS),
                Text(
                  state.message,
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

class _RestoreFormCard extends StatelessWidget {
  const _RestoreFormCard({
    required this.ftpServers,
    required this.selectedFtpServerId,
    required this.remoteFolderController,
    required this.localFolderController,
    required this.inputDecoration,
    required this.onFtpChanged,
    required this.onPickDestination,
  });

  final List<FtpServerModel> ftpServers;
  final String? selectedFtpServerId;
  final TextEditingController remoteFolderController;
  final TextEditingController localFolderController;
  final InputDecoration Function(String label, IconData icon) inputDecoration;
  final ValueChanged<String?>? onFtpChanged;
  final VoidCallback? onPickDestination;

  @override
  Widget build(BuildContext context) {
    return OBCard(
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: selectedFtpServerId,
            decoration: inputDecoration('FTP Server', AppIcons.server),
            items: ftpServers.map((server) {
              return DropdownMenuItem<String>(
                value: server.id,
                child: Text('${server.name} (${server.host}:${server.port})'),
              );
            }).toList(),
            onChanged: ftpServers.isEmpty ? null : onFtpChanged,
            validator: (value) =>
                value == null ? 'Add or select an FTP server' : null,
          ),
          const SizedBox(height: AppSizes.paddingM),
          TextFormField(
            controller: remoteFolderController,
            decoration: inputDecoration(
              'Remote Backup Folder',
              AppIcons.folder,
            ),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: AppSizes.paddingM),
          TextFormField(
            controller: localFolderController,
            readOnly: true,
            decoration: inputDecoration('Restore Destination', AppIcons.folder)
                .copyWith(
                  suffixIcon: IconButton(
                    tooltip: 'Select Restore Destination',
                    icon: const Icon(Icons.folder_open_rounded),
                    onPressed: onPickDestination,
                  ),
                ),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Required' : null,
          ),
        ],
      ),
    );
  }
}

class _PreviewList extends StatelessWidget {
  const _PreviewList({required this.state});

  final RestoreState state;

  @override
  Widget build(BuildContext context) {
    if (state.status == RestoreStatus.previewing ||
        state.status == RestoreStatus.running) {
      return const OBCard(child: Center(child: CircularProgressIndicator()));
    }

    if (state.previewFiles.isEmpty) {
      return const OBCard(child: Text('Preview results will appear here.'));
    }

    return OBCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${state.previewFiles.length} file(s) ready',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSizes.paddingS),
          Text(
            _formatBytes(
              state.previewFiles.fold<int>(0, (sum, file) => sum + file.size),
            ),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: AppSizes.paddingM),
          ...state.previewFiles.take(25).map((file) {
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.files),
              title: Text(file.relativePath),
              subtitle: Text(_formatBytes(file.size)),
            );
          }),
          if (state.previewFiles.length > 25)
            Padding(
              padding: const EdgeInsets.only(top: AppSizes.paddingS),
              child: Text(
                '+ ${state.previewFiles.length - 25} more file(s)',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textHint),
              ),
            ),
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }

    final mb = kb / 1024;
    if (mb < 1024) {
      return '${mb.toStringAsFixed(1)} MB';
    }

    return '${(mb / 1024).toStringAsFixed(1)} GB';
  }
}

class _MissingFtpServerCard extends StatelessWidget {
  const _MissingFtpServerCard();

  @override
  Widget build(BuildContext context) {
    return OBCard(
      child: Column(
        children: [
          const Icon(AppIcons.server, size: 48, color: AppColors.warning),
          const SizedBox(height: AppSizes.paddingM),
          Text('No FTP Server', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSizes.paddingS),
          Text(
            'Add an FTP server before restoring a backup.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: AppSizes.paddingM),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FtpServerListScreen()),
              );
            },
            icon: const Icon(AppIcons.server),
            label: const Text('Open FTP Servers'),
          ),
        ],
      ),
    );
  }
}
