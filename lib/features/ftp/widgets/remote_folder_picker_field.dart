import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../repositories/ftp_memory_repository.dart';
import '../models/ftp_server_model.dart';
import '../providers/ftp_provider.dart';

/// ===============================================================
/// OpenBackup
/// File : remote_folder_picker_field.dart
/// Version : 1.0.0
/// Description : Reusable FTP remote folder picker text field.
/// ===============================================================

class RemoteFolderPickerField extends ConsumerStatefulWidget {
  const RemoteFolderPickerField({
    super.key,
    required this.controller,
    required this.decoration,
    required this.ftpServer,
    this.enabled = true,
    this.validator,
    this.onChanged,
    this.onSelected,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final FtpServerModel? ftpServer;
  final bool enabled;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSelected;

  @override
  ConsumerState<RemoteFolderPickerField> createState() =>
      _RemoteFolderPickerFieldState();
}

class _RemoteFolderPickerFieldState
    extends ConsumerState<RemoteFolderPickerField> {
  bool _isSelecting = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      validator: widget.validator,
      decoration: widget.decoration.copyWith(
        suffixIcon: IconButton(
          tooltip: 'Select Remote Folder',
          onPressed: widget.enabled && !_isSelecting
              ? _selectRemoteFolder
              : null,
          icon: _isSelecting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.folder_open_rounded),
        ),
      ),
    );
  }

  Future<void> _selectRemoteFolder() async {
    final server = widget.ftpServer;
    if (server == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an FTP server first.')),
      );
      return;
    }

    setState(() {
      _isSelecting = true;
    });

    final selectedPath = await showDialog<String>(
      context: context,
      builder: (context) => _RemoteFolderPickerDialog(
        server: server,
        initialPath: widget.controller.text.trim().isEmpty
            ? '/'
            : widget.controller.text.trim(),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSelecting = false;
      if (selectedPath != null) {
        widget.controller.text = selectedPath;
      }
    });

    if (selectedPath != null) {
      widget.onSelected?.call(selectedPath);
      widget.onChanged?.call(selectedPath);
    }
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
  late final TextEditingController _pathController;
  var _currentPath = '/';
  var _isLoading = true;
  FtpRemoteFolderListResult? _result;

  @override
  void initState() {
    super.initState();
    _currentPath = _normalizeRemotePath(widget.initialPath);
    _pathController = TextEditingController(text: _currentPath);
    _loadFolders(_currentPath);
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _loadFolders(String remotePath) async {
    final normalizedPath = _normalizeRemotePath(remotePath);
    setState(() {
      _currentPath = normalizedPath;
      _pathController.text = normalizedPath;
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
      _pathController.text = result.currentPath;
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
            TextField(
              controller: _pathController,
              enabled: !_isLoading,
              decoration: const InputDecoration(
                labelText: 'Remote Path',
                prefixIcon: Icon(Icons.folder_rounded),
              ),
              textInputAction: TextInputAction.go,
              onSubmitted: _loadFolders,
            ),
            const SizedBox(height: AppSizes.paddingS),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => _loadFolders(_pathController.text),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Open Path'),
              ),
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
              : () => Navigator.pop(
                  context,
                  _normalizeRemotePath(_pathController.text),
                ),
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
    required this.folders,
    required this.onOpenParent,
    required this.onOpenFolder,
  });

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
