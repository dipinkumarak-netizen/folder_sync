import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../ftp/models/ftp_server_model.dart';
import '../../ftp/providers/ftp_provider.dart';
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

  String? _selectedFtpServerId;
  bool _enabled = true;

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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _localFolderController.dispose();
    _remoteFolderController.dispose();
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

  void _saveJob() {
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
      notifier.updateJob(job);
    } else {
      notifier.addJob(job);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ftpServers = ref.watch(ftpServerProvider);
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
              DropdownButtonFormField<String>(
                initialValue: _selectedFtpServerId,
                decoration: _inputDecoration('FTP Server', AppIcons.server),
                items: ftpServers.map((server) {
                  return DropdownMenuItem<String>(
                    value: server.id,
                    child: Text(_serverLabel(server)),
                  );
                }).toList(),
                onChanged: ftpServers.isEmpty
                    ? null
                    : (value) {
                        setState(() {
                          _selectedFtpServerId = value;
                        });
                      },
                validator: (value) =>
                    value == null ? 'Add or select an FTP server' : null,
              ),
              const SizedBox(height: AppSizes.paddingM),
              TextFormField(
                controller: _remoteFolderController,
                decoration: _inputDecoration('Remote Folder', AppIcons.folder),
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

  String _serverLabel(FtpServerModel server) {
    return '${server.name} (${server.host}:${server.port})';
  }
}
