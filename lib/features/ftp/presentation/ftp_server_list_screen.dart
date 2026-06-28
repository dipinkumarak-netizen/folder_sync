import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

/// ===============================================================
/// OpenBackup
/// File : ftp_server_list_screen.dart
/// Version : 1.0.0
/// Description : FTP Server List Screen
/// ===============================================================

class FtpServerListScreen extends StatelessWidget {
  const FtpServerListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Text("FTP Servers"),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // അടുത്ത ഘട്ടത്തിൽ Add Server Screen തുറക്കും.
        },
        child: const Icon(Icons.add),
      ),

      body: ListView(
        padding: const EdgeInsets.all(AppSizes.paddingM),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.paddingL),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
              border: Border.all(
                color: AppColors.border,
              ),
            ),
            child: Column(
              children: const [
                Icon(
                  Icons.dns_rounded,
                  size: 60,
                  color: Colors.blue,
                ),

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
                  style: TextStyle(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}