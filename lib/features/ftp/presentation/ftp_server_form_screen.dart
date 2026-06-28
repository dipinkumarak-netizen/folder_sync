import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

/// ===============================================================
/// OpenBackup
/// File : ftp_server_form_screen.dart
/// Version : 1.0.0
/// Description : Add/Edit FTP Server Form
/// ===============================================================

class FtpServerFormScreen extends StatefulWidget {
  const FtpServerFormScreen({super.key});

  @override
  State<FtpServerFormScreen> createState() => _FtpServerFormScreenState();
}

class _FtpServerFormScreenState extends State<FtpServerFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: "21");
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  final _remotePathController = TextEditingController(text: "/");

  bool _anonymousLogin = false;
  bool _showPassword = false;

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

  InputDecoration _inputDecoration(
      String label,
      IconData icon,
      ) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Add FTP Server"),
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
                value == null || value.isEmpty ? "Required" : null,
              ),

              const SizedBox(height: AppSizes.paddingM),

              TextFormField(
                controller: _hostController,
                decoration: _inputDecoration(
                  "Host / IP Address",
                  Icons.dns,
                ),
                validator: (value) =>
                value == null || value.isEmpty ? "Required" : null,
              ),

              const SizedBox(height: AppSizes.paddingM),

              TextFormField(
                controller: _portController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(
                  "Port",
                  Icons.settings_ethernet,
                ),
              ),

              const SizedBox(height: AppSizes.paddingM),

              TextFormField(
                controller: _userController,
                enabled: !_anonymousLogin,
                decoration: _inputDecoration(
                  "Username",
                  Icons.person,
                ),
              ),

              const SizedBox(height: AppSizes.paddingM),

              TextFormField(
                controller: _passwordController,
                enabled: !_anonymousLogin,
                obscureText: !_showPassword,
                decoration: _inputDecoration(
                  "Password",
                  Icons.lock,
                ).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
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
                decoration: _inputDecoration(
                  "Remote Folder",
                  Icons.folder,
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

              FilledButton.icon(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Save functionality will be added in the next step.",
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text("Save FTP Server"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}