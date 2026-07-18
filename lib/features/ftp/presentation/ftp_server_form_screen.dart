import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
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

  void _saveServer() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final server = _buildServerFromForm();
    final notifier = ref.read(ftpServerProvider.notifier);
    if (_isEditing) {
      notifier.updateServer(server);
    } else {
      notifier.addServer(server);
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
    final success = await ref
        .read(ftpServerProvider.notifier)
        .testConnection(server);

    if (!mounted) {
      return;
    }

    setState(() {
      _isTestingConnection = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? "FTP connection successful."
              : "Could not connect to the FTP server.",
        ),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );
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
                decoration: _inputDecoration("Remote Folder", Icons.folder),
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
