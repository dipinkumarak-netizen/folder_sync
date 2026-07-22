import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../ftp/models/ftp_server_model.dart';
import '../../ftp/providers/ftp_provider.dart';
import '../../ftp/widgets/remote_folder_picker_field.dart';
import '../../settings/providers/app_settings_provider.dart';
import '../models/backup_job_model.dart';
import '../providers/backup_provider.dart';

/// ===============================================================
/// OpenBackup
/// File : backup_job_form_screen.dart
/// Version : 1.0.0
/// Description : Add/Edit backup job form.
/// ===============================================================

class BackupJobFormScreen extends ConsumerStatefulWidget {
  const BackupJobFormScreen({super.key, this.job});

  final BackupJobModel? job;

  @override
  ConsumerState<BackupJobFormScreen> createState() =>
      _BackupJobFormScreenState();
}

class _BackupJobFormScreenState extends ConsumerState<BackupJobFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _localFolderController = TextEditingController();
  final _remoteFolderController = TextEditingController(text: '/');
  final _homeWifiController = TextEditingController();

  String? _selectedFtpServerId;
  bool _enabled = true;
  bool _runOnWifiOnly = true;
  bool _runOnlyWhileCharging = false;
  bool _compressBeforeUpload = false;
  bool _appliedSettingsDefaults = false;
  BackupScheduleRule _scheduleRule = BackupScheduleRule.manualOnly;

  bool get _isEditing => widget.job != null;

  @override
  void initState() {
    super.initState();

    final job = widget.job;
    if (job == null) {
      return;
    }

    _nameController.text = job.name;
    _localFolderController.text = job.localFolderPath;
    _remoteFolderController.text = job.remoteFolderPath;
    _selectedFtpServerId = job.ftpServerId;
    _enabled = job.enabled;
    _runOnWifiOnly = job.runOnWifiOnly;
    _runOnlyWhileCharging = job.runOnlyWhileCharging;
    _compressBeforeUpload = job.compressBeforeUpload;
    _homeWifiController.text = job.homeWifiName;
    _scheduleRule = job.scheduleRule;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _localFolderController.dispose();
    _remoteFolderController.dispose();
    _homeWifiController.dispose();
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

  Future<void> _pickFolder() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Backup Folder',
    );

    if (path == null || !mounted) {
      return;
    }

    _localFolderController.text = path;
  }

  Future<void> _saveJob() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final remoteFolder = _remoteFolderController.text.trim();
    final existingJob = widget.job;
    final job = BackupJobModel(
      id: existingJob?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      localFolderPath: _localFolderController.text.trim(),
      ftpServerId: _selectedFtpServerId!,
      remoteFolderPath: remoteFolder.isEmpty ? '/' : remoteFolder,
      enabled: _enabled,
      scheduleRule: _scheduleRule,
      runOnWifiOnly: _runOnWifiOnly,
      runOnlyWhileCharging: _runOnlyWhileCharging,
      compressBeforeUpload: _compressBeforeUpload,
      homeWifiName: _homeWifiController.text.trim(),
      status: existingJob?.status ?? BackupJobStatus.idle,
      lastRunAt: existingJob?.lastRunAt,
      lastMessage: existingJob?.lastMessage ?? 'Not run yet',
      lastFilesBackedUp: existingJob?.lastFilesBackedUp ?? 0,
      totalFilesBackedUp: existingJob?.totalFilesBackedUp ?? 0,
      totalBytesBackedUp: existingJob?.totalBytesBackedUp ?? 0,
      backedUpRelativePaths: existingJob?.backedUpRelativePaths ?? const [],
    );

    final notifier = ref.read(backupJobProvider.notifier);
    if (_isEditing) {
      await notifier.updateJob(job);
    } else {
      await notifier.addJob(job);
    }

    if (!mounted) {
      return;
    }

    Navigator.pop(context);
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
    final settingsLoad = ref.watch(appSettingsLoadProvider);
    final settings = ref.watch(appSettingsProvider);
    ref.watch(ftpServerLoadProvider);
    final ftpServers = ref.watch(ftpServerProvider);
    if (!_isEditing && !_appliedSettingsDefaults && settingsLoad.hasValue) {
      _runOnWifiOnly = settings.defaultBackupWifiOnly;
      _appliedSettingsDefaults = true;
    }
    if (_selectedFtpServerId == null && ftpServers.length == 1) {
      _selectedFtpServerId = ftpServers.first.id;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Backup Job' : 'Add Backup Job'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.paddingM),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration('Job Name', AppIcons.backup),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: AppSizes.paddingM),
              TextFormField(
                controller: _localFolderController,
                readOnly: true,
                decoration: _inputDecoration('Local Folder', AppIcons.folder)
                    .copyWith(
                      suffixIcon: IconButton(
                        tooltip: 'Select Local Folder',
                        icon: const Icon(Icons.folder_open_rounded),
                        onPressed: _pickFolder,
                      ),
                    ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: AppSizes.paddingM),
              _FtpServerDropdown(
                selectedFtpServerId: _selectedFtpServerId,
                ftpServers: ftpServers,
                inputDecoration: _inputDecoration(
                  'FTP Server',
                  AppIcons.server,
                ),
                onChanged: (value) {
                  setState(() {
                    _selectedFtpServerId = value;
                  });
                },
              ),
              const SizedBox(height: AppSizes.paddingM),
              RemoteFolderPickerField(
                controller: _remoteFolderController,
                ftpServer: _selectedFtpServer(ftpServers),
                decoration: _inputDecoration('Remote Folder', AppIcons.folder),
              ),
              const SizedBox(height: AppSizes.paddingM),
              _ScheduleDropdown(
                value: _scheduleRule,
                inputDecoration: _inputDecoration(
                  'Schedule',
                  AppIcons.schedule,
                ),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _scheduleRule = value;
                  });
                },
              ),
              const SizedBox(height: AppSizes.paddingM),
              SwitchListTile(
                value: _runOnWifiOnly,
                title: const Text('Run on Wi-Fi Only'),
                subtitle: const Text('Mobile data will not run this backup.'),
                onChanged: (value) {
                  setState(() {
                    _runOnWifiOnly = value;
                  });
                },
              ),
              const SizedBox(height: AppSizes.paddingM),
              SwitchListTile(
                value: _runOnlyWhileCharging,
                title: const Text('Run Only While Charging'),
                subtitle: const Text(
                  'Backup will wait until device is plugged in.',
                ),
                onChanged: (value) {
                  setState(() {
                    _runOnlyWhileCharging = value;
                  });
                },
              ),
              SwitchListTile(
                value: _compressBeforeUpload,
                title: const Text('Compress Before Upload'),
                subtitle: const Text('Reduces data usage by zipping files.'),
                onChanged: (value) {
                  setState(() {
                    _compressBeforeUpload = value;
                  });
                },
              ),
              const SizedBox(height: AppSizes.paddingM),
              TextFormField(
                controller: _homeWifiController,
                decoration: _inputDecoration('Home Wi-Fi Name', AppIcons.wifi),
              ),
              const SizedBox(height: AppSizes.paddingM),
              SwitchListTile(
                value: _enabled,
                title: const Text('Enabled'),
                subtitle: const Text('Disabled jobs cannot be run.'),
                onChanged: (value) {
                  setState(() {
                    _enabled = value;
                  });
                },
              ),
              const SizedBox(height: AppSizes.paddingXL),
              FilledButton.icon(
                onPressed: _saveJob,
                icon: const Icon(AppIcons.save),
                label: Text(
                  _isEditing ? 'Update Backup Job' : 'Save Backup Job',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleDropdown extends StatelessWidget {
  const _ScheduleDropdown({
    required this.value,
    required this.inputDecoration,
    required this.onChanged,
  });

  final BackupScheduleRule value;
  final InputDecoration inputDecoration;
  final ValueChanged<BackupScheduleRule?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<BackupScheduleRule>(
      initialValue: value,
      decoration: inputDecoration,
      items: BackupScheduleRule.values.map((rule) {
        return DropdownMenuItem<BackupScheduleRule>(
          value: rule,
          child: Text(_scheduleLabel(rule)),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  String _scheduleLabel(BackupScheduleRule value) {
    return switch (value) {
      BackupScheduleRule.manualOnly => 'Manual Only',
      BackupScheduleRule.instant => 'Instant Backup',
      BackupScheduleRule.hourly => 'Hourly',
      BackupScheduleRule.daily => 'Daily',
      BackupScheduleRule.onHomeWifi => 'On Home Wi-Fi',
    };
  }
}

class _FtpServerDropdown extends StatelessWidget {
  const _FtpServerDropdown({
    required this.selectedFtpServerId,
    required this.ftpServers,
    required this.inputDecoration,
    required this.onChanged,
  });

  final String? selectedFtpServerId;
  final List<FtpServerModel> ftpServers;
  final InputDecoration inputDecoration;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: selectedFtpServerId,
      decoration: inputDecoration,
      items: ftpServers.map((server) {
        return DropdownMenuItem<String>(
          value: server.id,
          child: Text('${server.name} (${server.host}:${server.port})'),
        );
      }).toList(),
      onChanged: ftpServers.isEmpty ? null : onChanged,
      validator: (value) =>
          value == null ? 'Add or select an FTP server' : null,
    );
  }
}
