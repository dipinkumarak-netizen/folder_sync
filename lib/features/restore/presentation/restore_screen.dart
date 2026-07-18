import 'dart:async';

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
import '../../repositories/restore_repository.dart';
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
  final _includePatternsController = TextEditingController(text: '*');
  final _excludePatternsController = TextEditingController();
  final _maxFileSizeController = TextEditingController();

  String? _selectedFtpServerId;
  bool _includeSubfolders = true;
  bool _includeHiddenFiles = false;
  RestoreConflictRule _conflictRule = RestoreConflictRule.skipExisting;

  @override
  void dispose() {
    _remoteFolderController.dispose();
    _localFolderController.dispose();
    _includePatternsController.dispose();
    _excludePatternsController.dispose();
    _maxFileSizeController.dispose();
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
    _refreshConflictPreview();
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
          localFolderPath: _localFolderController.text.trim(),
          conflictRule: _conflictRule,
          filterOptions: _filterOptions(),
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
          content: Text(_confirmationMessage(_conflictRule)),
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
          conflictRule: _conflictRule,
          filterOptions: _filterOptions(),
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
                includePatternsController: _includePatternsController,
                excludePatternsController: _excludePatternsController,
                maxFileSizeController: _maxFileSizeController,
                conflictRule: _conflictRule,
                includeSubfolders: _includeSubfolders,
                includeHiddenFiles: _includeHiddenFiles,
                inputDecoration: _inputDecoration,
                onFtpChanged: isBusy
                    ? null
                    : (value) {
                        setState(() {
                          _selectedFtpServerId = value;
                        });
                        _clearPreviewAfterInputChange();
                      },
                onPickDestination: isBusy ? null : _pickDestinationFolder,
                onRemoteFolderChanged: isBusy
                    ? null
                    : (_) => _clearPreviewAfterInputChange(),
                onIncludeSubfoldersChanged: isBusy
                    ? null
                    : (value) {
                        setState(() {
                          _includeSubfolders = value;
                        });
                        _clearPreviewAfterInputChange();
                      },
                onIncludeHiddenFilesChanged: isBusy
                    ? null
                    : (value) {
                        setState(() {
                          _includeHiddenFiles = value;
                        });
                        _clearPreviewAfterInputChange();
                      },
                onFiltersChanged: isBusy ? null : _clearPreviewAfterInputChange,
                onConflictChanged: isBusy
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          _conflictRule = value;
                        });
                        _refreshConflictPreview();
                      },
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
              _PreviewList(state: restoreState, conflictRule: _conflictRule),
            ],
          ),
        ),
      ),
    );
  }

  String _confirmationMessage(RestoreConflictRule conflictRule) {
    return switch (conflictRule) {
      RestoreConflictRule.skipExisting =>
        'Files that already exist in the destination folder will be skipped.',
      RestoreConflictRule.overwriteExisting =>
        'Existing destination files with the same path will be overwritten.',
      RestoreConflictRule.keepBoth =>
        'Existing destination files will be kept and restored files will get copy names.',
    };
  }

  void _refreshConflictPreview() {
    final localFolderPath = _localFolderController.text.trim();
    final restoreState = ref.read(restoreProvider);
    if (localFolderPath.isEmpty || restoreState.previewFiles.isEmpty) {
      return;
    }

    unawaited(
      ref
          .read(restoreProvider.notifier)
          .refreshConflictPreview(
            localFolderPath: localFolderPath,
            conflictRule: _conflictRule,
          ),
    );
  }

  void _clearPreviewAfterInputChange() {
    ref
        .read(restoreProvider.notifier)
        .clearPreview('Restore options changed. Preview files again.');
  }

  RestoreFilterOptions _filterOptions() {
    final maxFileSizeText = _maxFileSizeController.text.trim();
    return RestoreFilterOptions(
      includeSubfolders: _includeSubfolders,
      includeHiddenFiles: _includeHiddenFiles,
      includePatterns: _includePatternsController.text.trim().isEmpty
          ? '*'
          : _includePatternsController.text.trim(),
      excludePatterns: _excludePatternsController.text.trim(),
      maxFileSizeMb: maxFileSizeText.isEmpty
          ? null
          : int.parse(maxFileSizeText),
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
                if (state.status == RestoreStatus.running) ...[
                  const SizedBox(height: AppSizes.paddingM),
                  LinearProgressIndicator(value: _progressValue(state)),
                  const SizedBox(height: AppSizes.paddingS),
                  Text(
                    _progressLabel(state),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textHint),
                  ),
                  if (state.currentFilePath.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.paddingXS),
                    Text(
                      state.currentFilePath,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  double? _progressValue(RestoreState state) {
    if (state.totalFiles == 0) {
      return null;
    }

    return state.currentFileIndex / state.totalFiles;
  }

  String _progressLabel(RestoreState state) {
    final totalFiles = state.totalFiles;
    if (totalFiles == 0) {
      return 'Preparing files...';
    }

    return '${state.currentFileIndex}/$totalFiles file(s), '
        '${state.lastFilesRestored} restored, '
        '${state.lastFilesSkipped} skipped';
  }
}

class _RestoreFormCard extends StatelessWidget {
  const _RestoreFormCard({
    required this.ftpServers,
    required this.selectedFtpServerId,
    required this.remoteFolderController,
    required this.localFolderController,
    required this.includePatternsController,
    required this.excludePatternsController,
    required this.maxFileSizeController,
    required this.conflictRule,
    required this.includeSubfolders,
    required this.includeHiddenFiles,
    required this.inputDecoration,
    required this.onFtpChanged,
    required this.onPickDestination,
    required this.onRemoteFolderChanged,
    required this.onIncludeSubfoldersChanged,
    required this.onIncludeHiddenFilesChanged,
    required this.onFiltersChanged,
    required this.onConflictChanged,
  });

  final List<FtpServerModel> ftpServers;
  final String? selectedFtpServerId;
  final TextEditingController remoteFolderController;
  final TextEditingController localFolderController;
  final TextEditingController includePatternsController;
  final TextEditingController excludePatternsController;
  final TextEditingController maxFileSizeController;
  final RestoreConflictRule conflictRule;
  final bool includeSubfolders;
  final bool includeHiddenFiles;
  final InputDecoration Function(String label, IconData icon) inputDecoration;
  final ValueChanged<String?>? onFtpChanged;
  final VoidCallback? onPickDestination;
  final ValueChanged<String>? onRemoteFolderChanged;
  final ValueChanged<bool>? onIncludeSubfoldersChanged;
  final ValueChanged<bool>? onIncludeHiddenFilesChanged;
  final VoidCallback? onFiltersChanged;
  final ValueChanged<RestoreConflictRule?>? onConflictChanged;

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
            onChanged: onRemoteFolderChanged,
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
          const SizedBox(height: AppSizes.paddingM),
          DropdownButtonFormField<RestoreConflictRule>(
            initialValue: conflictRule,
            decoration: inputDecoration('Conflict Rule', AppIcons.warning),
            items: RestoreConflictRule.values.map((rule) {
              return DropdownMenuItem<RestoreConflictRule>(
                value: rule,
                child: Text(_conflictLabel(rule)),
              );
            }).toList(),
            onChanged: onConflictChanged,
          ),
          const SizedBox(height: AppSizes.paddingM),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: includeSubfolders,
            title: const Text('Restore Subfolders'),
            onChanged: onIncludeSubfoldersChanged,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: includeHiddenFiles,
            title: const Text('Include Hidden Files'),
            onChanged: onIncludeHiddenFilesChanged,
          ),
          const SizedBox(height: AppSizes.paddingM),
          TextFormField(
            controller: includePatternsController,
            decoration: inputDecoration('Include Patterns', AppIcons.files),
            onChanged: (_) => onFiltersChanged?.call(),
          ),
          const SizedBox(height: AppSizes.paddingM),
          TextFormField(
            controller: excludePatternsController,
            decoration: inputDecoration('Exclude Patterns', AppIcons.files),
            onChanged: (_) => onFiltersChanged?.call(),
          ),
          const SizedBox(height: AppSizes.paddingM),
          TextFormField(
            controller: maxFileSizeController,
            keyboardType: TextInputType.number,
            decoration: inputDecoration('Max File Size MB', AppIcons.storage),
            onChanged: (_) => onFiltersChanged?.call(),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) {
                return null;
              }

              final size = int.tryParse(text);
              if (size == null || size < 1) {
                return 'Enter a valid size';
              }

              return null;
            },
          ),
        ],
      ),
    );
  }

  String _conflictLabel(RestoreConflictRule rule) {
    return switch (rule) {
      RestoreConflictRule.skipExisting => 'Skip Existing',
      RestoreConflictRule.overwriteExisting => 'Overwrite Existing',
      RestoreConflictRule.keepBoth => 'Keep Both',
    };
  }
}

class _PreviewList extends StatelessWidget {
  const _PreviewList({required this.state, required this.conflictRule});

  final RestoreState state;
  final RestoreConflictRule conflictRule;

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
          _ConflictSummary(
            state: state,
            conflictRule: conflictRule,
            formatBytes: _formatBytes,
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

class _ConflictSummary extends StatelessWidget {
  const _ConflictSummary({
    required this.state,
    required this.conflictRule,
    required this.formatBytes,
  });

  final RestoreState state;
  final RestoreConflictRule conflictRule;
  final String Function(int bytes) formatBytes;

  @override
  Widget build(BuildContext context) {
    final summary = state.conflictPreview;
    final conflictCount = summary.existingConflicts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSizes.paddingS,
          runSpacing: AppSizes.paddingS,
          children: [
            _SummaryBadge(
              label: 'Restore ${summary.filesToRestore}',
              color: AppColors.success,
            ),
            _SummaryBadge(
              label: 'Conflicts $conflictCount',
              color: conflictCount == 0 ? AppColors.success : AppColors.warning,
            ),
            _SummaryBadge(
              label: 'Skip ${summary.filesSkipped}',
              color: AppColors.textHint,
            ),
            _SummaryBadge(
              label: 'Overwrite ${summary.filesOverwritten}',
              color: AppColors.error,
            ),
            _SummaryBadge(
              label: 'Keep Both ${summary.filesKeptBoth}',
              color: AppColors.info,
            ),
          ],
        ),
        const SizedBox(height: AppSizes.paddingS),
        Text(
          '${_conflictRuleLabel(conflictRule)} will restore ${summary.filesToRestore} file(s), ${formatBytes(summary.bytesToRestore)}.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textHint),
        ),
        if (summary.conflictingFiles.isNotEmpty) ...[
          const SizedBox(height: AppSizes.paddingM),
          Text(
            'Local Conflicts',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSizes.paddingS),
          ...summary.conflictingFiles.take(10).map((file) {
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.warning, color: AppColors.warning),
              title: Text(file.relativePath),
              subtitle: Text(_conflictActionLabel(conflictRule)),
            );
          }),
          if (summary.conflictingFiles.length > 10)
            Text(
              '+ ${summary.conflictingFiles.length - 10} more conflict(s)',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textHint),
            ),
        ],
      ],
    );
  }

  String _conflictRuleLabel(RestoreConflictRule rule) {
    return switch (rule) {
      RestoreConflictRule.skipExisting => 'Skip Existing',
      RestoreConflictRule.overwriteExisting => 'Overwrite Existing',
      RestoreConflictRule.keepBoth => 'Keep Both',
    };
  }

  String _conflictActionLabel(RestoreConflictRule rule) {
    return switch (rule) {
      RestoreConflictRule.skipExisting => 'Will be skipped',
      RestoreConflictRule.overwriteExisting => 'Will be overwritten',
      RestoreConflictRule.keepBoth => 'Will be restored as a copy',
    };
  }
}

class _SummaryBadge extends StatelessWidget {
  const _SummaryBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingS,
        vertical: AppSizes.paddingXS,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
    );
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
