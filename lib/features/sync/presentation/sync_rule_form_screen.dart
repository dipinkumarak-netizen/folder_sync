import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_sizes.dart';
import '../../ftp/models/ftp_server_model.dart';
import '../../ftp/providers/ftp_provider.dart';
import '../../settings/providers/app_settings_provider.dart';
import '../models/sync_rule_model.dart';
import '../providers/sync_rule_provider.dart';

/// ===============================================================
/// OpenBackup
/// File : sync_rule_form_screen.dart
/// Version : 1.0.0
/// Description : Add/Edit synchronization rule form.
/// ===============================================================

class SyncRuleFormScreen extends ConsumerStatefulWidget {
  const SyncRuleFormScreen({super.key, this.rule});

  final SyncRuleModel? rule;

  @override
  ConsumerState<SyncRuleFormScreen> createState() => _SyncRuleFormScreenState();
}

class _SyncRuleFormScreenState extends ConsumerState<SyncRuleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _localFolderController = TextEditingController();
  final _remoteFolderController = TextEditingController(text: '/');
  final _homeWifiController = TextEditingController();
  final _includePatternsController = TextEditingController(text: '*');
  final _excludePatternsController = TextEditingController();
  final _maxFileSizeController = TextEditingController();

  String? _selectedFtpServerId;
  bool _enabled = true;
  bool _syncSubfolders = true;
  bool _includeHiddenFiles = false;
  bool _runOnWifiOnly = true;
  bool _appliedSettingsDefaults = false;
  SyncDirection _direction = SyncDirection.twoWay;
  SyncConflictRule _conflictRule = SyncConflictRule.newerWins;
  SyncDeleteRule _deleteRule = SyncDeleteRule.keepDeletedFiles;
  SyncTriggerRule _triggerRule = SyncTriggerRule.manualOnly;

  bool get _isEditing => widget.rule != null;

  @override
  void initState() {
    super.initState();

    final rule = widget.rule;
    if (rule == null) {
      return;
    }

    _nameController.text = rule.name;
    _localFolderController.text = rule.localFolderPath;
    _remoteFolderController.text = rule.remoteFolderPath;
    _homeWifiController.text = rule.homeWifiName;
    _includePatternsController.text = rule.includePatterns;
    _excludePatternsController.text = rule.excludePatterns;
    _maxFileSizeController.text = rule.maxFileSizeMb?.toString() ?? '';
    _selectedFtpServerId = rule.ftpServerId;
    _enabled = rule.enabled;
    _syncSubfolders = rule.syncSubfolders;
    _includeHiddenFiles = rule.includeHiddenFiles;
    _runOnWifiOnly = rule.runOnWifiOnly;
    _direction = rule.direction;
    _conflictRule = rule.conflictRule;
    _deleteRule = rule.deleteRule;
    _triggerRule = rule.triggerRule;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _localFolderController.dispose();
    _remoteFolderController.dispose();
    _homeWifiController.dispose();
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

  Future<void> _pickFolder() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Sync Folder',
    );

    if (path == null || !mounted) {
      return;
    }

    _localFolderController.text = path;
  }

  Future<void> _saveRule() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final remoteFolder = _remoteFolderController.text.trim();
    final maxFileSizeText = _maxFileSizeController.text.trim();
    final existingRule = widget.rule;
    final rule = SyncRuleModel(
      id: existingRule?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      localFolderPath: _localFolderController.text.trim(),
      ftpServerId: _selectedFtpServerId!,
      remoteFolderPath: remoteFolder.isEmpty ? '/' : remoteFolder,
      enabled: _enabled,
      direction: _direction,
      conflictRule: _conflictRule,
      deleteRule: _deleteRule,
      triggerRule: _triggerRule,
      syncSubfolders: _syncSubfolders,
      includeHiddenFiles: _includeHiddenFiles,
      runOnWifiOnly: _runOnWifiOnly,
      homeWifiName: _homeWifiController.text.trim(),
      includePatterns: _includePatternsController.text.trim().isEmpty
          ? '*'
          : _includePatternsController.text.trim(),
      excludePatterns: _excludePatternsController.text.trim(),
      maxFileSizeMb: maxFileSizeText.isEmpty
          ? null
          : int.parse(maxFileSizeText),
      status: existingRule?.status ?? SyncRuleStatus.idle,
      lastRunAt: existingRule?.lastRunAt,
      lastMessage: existingRule?.lastMessage ?? 'Not run yet',
      lastFilesChanged: existingRule?.lastFilesChanged ?? 0,
      totalFilesChanged: existingRule?.totalFilesChanged ?? 0,
      totalBytesChanged: existingRule?.totalBytesChanged ?? 0,
    );

    final notifier = ref.read(syncRuleProvider.notifier);
    if (_isEditing) {
      await notifier.updateRule(rule);
    } else {
      await notifier.addRule(rule);
    }

    if (!mounted) {
      return;
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final settingsLoad = ref.watch(appSettingsLoadProvider);
    final settings = ref.watch(appSettingsProvider);
    ref.watch(ftpServerLoadProvider);
    final ftpServers = ref.watch(ftpServerProvider);
    if (!_isEditing && !_appliedSettingsDefaults && settingsLoad.hasValue) {
      _runOnWifiOnly = settings.defaultSyncWifiOnly;
      _appliedSettingsDefaults = true;
    }
    if (_selectedFtpServerId == null && ftpServers.length == 1) {
      _selectedFtpServerId = ftpServers.first.id;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Sync Rule' : 'Add Sync Rule'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.paddingM),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration('Rule Name', AppIcons.sync),
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
              TextFormField(
                controller: _remoteFolderController,
                decoration: _inputDecoration('Remote Folder', AppIcons.folder),
              ),
              const SizedBox(height: AppSizes.paddingM),
              _EnumDropdown<SyncDirection>(
                label: 'Direction',
                icon: AppIcons.sync,
                value: _direction,
                values: SyncDirection.values,
                labelBuilder: _directionLabel,
                onChanged: (value) => setState(() => _direction = value),
              ),
              const SizedBox(height: AppSizes.paddingM),
              _EnumDropdown<SyncConflictRule>(
                label: 'Conflict Rule',
                icon: AppIcons.warning,
                value: _conflictRule,
                values: SyncConflictRule.values,
                labelBuilder: _conflictLabel,
                onChanged: (value) => setState(() => _conflictRule = value),
              ),
              const SizedBox(height: AppSizes.paddingM),
              _EnumDropdown<SyncDeleteRule>(
                label: 'Delete Rule',
                icon: AppIcons.delete,
                value: _deleteRule,
                values: SyncDeleteRule.values,
                labelBuilder: _deleteLabel,
                onChanged: (value) => setState(() => _deleteRule = value),
              ),
              const SizedBox(height: AppSizes.paddingM),
              _EnumDropdown<SyncTriggerRule>(
                label: 'Trigger',
                icon: AppIcons.schedule,
                value: _triggerRule,
                values: SyncTriggerRule.values,
                labelBuilder: _triggerLabel,
                onChanged: (value) => setState(() => _triggerRule = value),
              ),
              const SizedBox(height: AppSizes.paddingM),
              SwitchListTile(
                value: _runOnWifiOnly,
                title: const Text('Run on Wi-Fi Only'),
                subtitle: const Text('Prevents mobile-data synchronization.'),
                onChanged: (value) => setState(() => _runOnWifiOnly = value),
              ),
              TextFormField(
                controller: _homeWifiController,
                decoration: _inputDecoration('Home Wi-Fi Name', AppIcons.wifi),
              ),
              const SizedBox(height: AppSizes.paddingM),
              SwitchListTile(
                value: _syncSubfolders,
                title: const Text('Sync Subfolders'),
                onChanged: (value) => setState(() => _syncSubfolders = value),
              ),
              SwitchListTile(
                value: _includeHiddenFiles,
                title: const Text('Include Hidden Files'),
                onChanged: (value) =>
                    setState(() => _includeHiddenFiles = value),
              ),
              SwitchListTile(
                value: _enabled,
                title: const Text('Enabled'),
                onChanged: (value) => setState(() => _enabled = value),
              ),
              const SizedBox(height: AppSizes.paddingM),
              TextFormField(
                controller: _includePatternsController,
                decoration: _inputDecoration(
                  'Include Patterns',
                  AppIcons.files,
                ),
              ),
              const SizedBox(height: AppSizes.paddingM),
              TextFormField(
                controller: _excludePatternsController,
                decoration: _inputDecoration(
                  'Exclude Patterns',
                  AppIcons.files,
                ),
              ),
              const SizedBox(height: AppSizes.paddingM),
              TextFormField(
                controller: _maxFileSizeController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(
                  'Max File Size MB',
                  AppIcons.storage,
                ),
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
              const SizedBox(height: AppSizes.paddingXL),
              FilledButton.icon(
                onPressed: _saveRule,
                icon: const Icon(AppIcons.save),
                label: Text(_isEditing ? 'Update Sync Rule' : 'Save Sync Rule'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _directionLabel(SyncDirection value) {
    return switch (value) {
      SyncDirection.uploadOnly => 'Upload Only',
      SyncDirection.downloadOnly => 'Download Only',
      SyncDirection.twoWay => 'Two-Way Sync',
      SyncDirection.mirrorLocalToRemote => 'Mirror Local to Remote',
      SyncDirection.mirrorRemoteToLocal => 'Mirror Remote to Local',
    };
  }

  String _conflictLabel(SyncConflictRule value) {
    return switch (value) {
      SyncConflictRule.newerWins => 'Newest File Wins',
      SyncConflictRule.localWins => 'Local File Wins',
      SyncConflictRule.remoteWins => 'Remote File Wins',
      SyncConflictRule.keepBoth => 'Keep Both Copies',
      SyncConflictRule.skip => 'Skip Conflicts',
    };
  }

  String _deleteLabel(SyncDeleteRule value) {
    return switch (value) {
      SyncDeleteRule.keepDeletedFiles => 'Keep Deleted Files',
      SyncDeleteRule.deleteRemoteWhenLocalDeleted => 'Delete Remote',
      SyncDeleteRule.deleteLocalWhenRemoteDeleted => 'Delete Local',
      SyncDeleteRule.deleteBothWays => 'Delete Both Ways',
    };
  }

  String _triggerLabel(SyncTriggerRule value) {
    return switch (value) {
      SyncTriggerRule.manualOnly => 'Manual Only',
      SyncTriggerRule.onHomeWifi => 'When Home Wi-Fi Connects',
      SyncTriggerRule.hourly => 'Hourly',
      SyncTriggerRule.daily => 'Daily',
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

class _EnumDropdown<T> extends StatelessWidget {
  const _EnumDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.values,
    required this.labelBuilder,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final T value;
  final List<T> values;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
        ),
      ),
      items: values.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(labelBuilder(item)),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}
