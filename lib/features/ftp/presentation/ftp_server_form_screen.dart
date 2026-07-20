import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../repositories/ftp_memory_repository.dart';
import '../models/ftp_server_model.dart';
import '../providers/ftp_provider.dart';

/// ===============================================================
/// OpenBackup
/// File : ftp_server_form_screen.dart
/// Version : 1.2.0
/// Description : Add/Edit FTP Server Form
/// ===============================================================

class FtpServerFormScreen extends ConsumerStatefulWidget {
  const FtpServerFormScreen({super.key, this.server});

  final FtpServerModel? server;

  @override
  ConsumerState<FtpServerFormScreen> createState() =>
      _FtpServerFormScreenState();
}

class _FtpServerFormScreenState extends ConsumerState<FtpServerFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: "21");
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  final _remotePathController = TextEditingController(text: "/");

  bool _anonymousLogin = false;
  bool _showPassword = false;
  bool _isTestingConnection = false;
  bool _isSelectingRemoteFolder = false;

  bool get _isEditing => widget.server != null;

  @override
  void initState() {
    super.initState();

    final server = widget.server;
    if (server == null) {
      return;
    }

    _nameController.text = server.name;
    _hostController.text = server.host;
    _portController.text = server.port.toString();
    _userController.text = server.username;
    _passwordController.text = server.password;
    _remotePathController.text = server.remotePath;
    _anonymousLogin = server.isAnonymous;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    _remotePathController.dispose();
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

  FtpServerModel _buildServerFromForm() {
    final remotePath = _remotePathController.text.trim();
    return FtpServerModel(
      id: widget.server?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      host: _hostController.text.trim(),
      port: int.parse(_portController.text.trim()),
      username: _anonymousLogin ? '' : _userController.text.trim(),
      password: _anonymousLogin ? '' : _passwordController.text,
      remotePath: remotePath.isEmpty ? '/' : remotePath,
      isAnonymous: _anonymousLogin,
      isFavorite: widget.server?.isFavorite ?? false,
    );
  }

  Future<void> _saveServer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final server = _buildServerFromForm();
    final notifier = ref.read(ftpServerProvider.notifier);
    if (_isEditing) {
      await notifier.updateServer(server);
    } else {
      await notifier.addServer(server);
    }

    if (!mounted) {
      return;
    }

    Navigator.pop(context);
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isTestingConnection = true;
    });

    final server = _buildServerFromForm();
    final result = await ref
        .read(ftpServerProvider.notifier)
        .testConnectionDetailed(server);

    if (!mounted) {
      return;
    }

    setState(() {
      _isTestingConnection = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? AppColors.success : AppColors.error,
      ),
    );
  }

  Future<void> _selectRemoteFolder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSelectingRemoteFolder = true;
    });

    final selectedPath = await showDialog<String>(
      context: context,
      builder: (context) => _RemoteFolderPickerDialog(
        server: _buildServerFromForm(),
        initialPath: _remotePathController.text.trim().isEmpty
            ? '/'
            : _remotePathController.text.trim(),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSelectingRemoteFolder = false;
      if (selectedPath != null) {
        _remotePathController.text = selectedPath;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? "Edit FTP Server" : "Add FTP Server"),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.paddingM),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration(
                  "Server Name",
                  Icons.label_outline,
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? "Required" : null,
              ),
              const SizedBox(height: AppSizes.paddingM),
              TextFormField(
                controller: _hostController,
                decoration: _inputDecoration("Host / IP Address", Icons.dns),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? "Required" : null,
              ),
              const SizedBox(height: AppSizes.paddingM),
              TextFormField(
                controller: _portController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration("Port", Icons.settings_ethernet),
                validator: (value) {
                  final port = int.tryParse(value?.trim() ?? '');
                  if (port == null) {
                    return "Enter a valid port";
                  }

                  if (port < 1 || port > 65535) {
                    return "Port must be between 1 and 65535";
                  }

                  return null;
                },
              ),
              const SizedBox(height: AppSizes.paddingM),
              TextFormField(
                controller: _userController,
                enabled: !_anonymousLogin,
                decoration: _inputDecoration("Username", Icons.person),
                validator: (value) {
                  if (_anonymousLogin) {
                    return null;
                  }

                  return value == null || value.trim().isEmpty
                      ? "Required"
                      : null;
                },
              ),
              const SizedBox(height: AppSizes.paddingM),
              TextFormField(
                controller: _passwordController,
                enabled: !_anonymousLogin,
                obscureText: !_showPassword,
                decoration: _inputDecoration("Password", Icons.lock).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _showPassword = !_showPassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.paddingM),
              TextFormField(
                controller: _remotePathController,
                decoration: _inputDecoration("Remote Folder", Icons.folder)
                    .copyWith(
                      suffixIcon: IconButton(
                        tooltip: 'Select Remote Folder',
                        onPressed: _isSelectingRemoteFolder
                            ? null
                            : _selectRemoteFolder,
                        icon: _isSelectingRemoteFolder
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.folder_open_rounded),
                      ),
                    ),
              ),
              const SizedBox(height: AppSizes.paddingM),
              SwitchListTile(
                value: _anonymousLogin,
                title: const Text("Anonymous Login"),
                onChanged: (value) {
                  setState(() {
                    _anonymousLogin = value;
                  });
                },
              ),
              const SizedBox(height: AppSizes.paddingXL),
              OutlinedButton.icon(
                onPressed: _isTestingConnection ? null : _testConnection,
                icon: _isTestingConnection
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering_rounded),
                label: Text(
                  _isTestingConnection
                      ? "Testing Connection"
                      : "Test Connection",
                ),
              ),
              const SizedBox(height: AppSizes.paddingM),
              FilledButton.icon(
                onPressed: _isTestingConnection ? null : _saveServer,
                icon: const Icon(Icons.save),
                label: Text(
                  _isEditing ? "Update FTP Server" : "Save FTP Server",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemoteFolderPickerDialog extends ConsumerStatefulWidget {
  const _RemoteFolderPickerDialog({
    required this.server,
    required this.initialPath,
  });

  final FtpServerModel server;
  final String initialPath;

  @override
  ConsumerState<_RemoteFolderPickerDialog> createState() =>
      _RemoteFolderPickerDialogState();
}

class _RemoteFolderPickerDialogState
    extends ConsumerState<_RemoteFolderPickerDialog> {
  var _currentPath = '/';
  var _isLoading = true;
  FtpRemoteFolderListResult? _result;

  @override
  void initState() {
    super.initState();
    _currentPath = _normalizeRemotePath(widget.initialPath);
    _loadFolders(_currentPath);
  }

  Future<void> _loadFolders(String remotePath) async {
    setState(() {
      _currentPath = _normalizeRemotePath(remotePath);
      _isLoading = true;
    });

    final result = await ref
        .read(ftpServerProvider.notifier)
        .listRemoteFolders(server: widget.server, remotePath: _currentPath);

    if (!mounted) {
      return;
    }

    setState(() {
      _result = result;
      _currentPath = result.currentPath;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return AlertDialog(
      title: const Text('Select Remote Folder'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentPath,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textHint),
            ),
            const SizedBox(height: AppSizes.paddingM),
            Flexible(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : result == null || !result.success
                  ? _RemoteFolderError(
                      message: result?.message ?? 'Could not load folders.',
                      onRetry: () => _loadFolders(_currentPath),
                    )
                  : _RemoteFolderList(
                      currentPath: _currentPath,
                      folders: result.folders,
                      onOpenParent: _canOpenParent
                          ? () => _loadFolders(_parentPath(_currentPath))
                          : null,
                      onOpenFolder: (folder) => _loadFolders(folder.path),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading
              ? null
              : () => Navigator.pop(context, _currentPath),
          child: const Text('Select Folder'),
        ),
      ],
    );
  }

  bool get _canOpenParent => _currentPath != '/';

  String _normalizeRemotePath(String remotePath) {
    final trimmed = remotePath.trim();
    if (trimmed.isEmpty || trimmed == '.') {
      return '/';
    }

    final normalized = trimmed.replaceAll(RegExp(r'/+'), '/');
    if (normalized == '/') {
      return '/';
    }

    return normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }

  String _parentPath(String remotePath) {
    final normalized = _normalizeRemotePath(remotePath);
    if (normalized == '/') {
      return '/';
    }

    final parts = normalized.split('/').where((part) => part.isNotEmpty);
    final parentParts = parts.take(parts.length - 1).toList();
    if (parentParts.isEmpty) {
      return '/';
    }

    return '/${parentParts.join('/')}';
  }
}

class _RemoteFolderList extends StatelessWidget {
  const _RemoteFolderList({
    required this.currentPath,
    required this.folders,
    required this.onOpenParent,
    required this.onOpenFolder,
  });

  final String currentPath;
  final List<FtpRemoteFolderEntry> folders;
  final VoidCallback? onOpenParent;
  final ValueChanged<FtpRemoteFolderEntry> onOpenFolder;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 360),
      child: ListView(
        shrinkWrap: true,
        children: [
          if (onOpenParent != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.drive_folder_upload_rounded),
              title: const Text('Parent Folder'),
              onTap: onOpenParent,
            ),
          if (folders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.paddingL),
              child: Text(
                'No folders found here.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textHint),
              ),
            ),
          ...folders.map(
            (folder) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder_rounded),
              title: Text(folder.name),
              subtitle: Text(folder.path),
              onTap: () => onOpenFolder(folder),
            ),
          ),
        ],
      ),
    );
  }
}

class _RemoteFolderError extends StatelessWidget {
  const _RemoteFolderError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textHint),
        ),
        const SizedBox(height: AppSizes.paddingM),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}
