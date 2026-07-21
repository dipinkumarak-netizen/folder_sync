import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../features/dashboard/presentation/home_screen.dart';
import '../../features/settings/presentation/onboarding_readiness_screen.dart';
import '../../features/settings/providers/app_settings_provider.dart';

/// ===============================================================
/// OpenBackup
/// File : splash_screen.dart
/// Version : 1.1.0
/// Layer : Splash
/// Description : Splash screen.
/// ===============================================================

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    await ref.read(appSettingsProvider.notifier).loadSettings();
    final settings = ref.read(appSettingsProvider);

    if (settings.biometricLockEnabled) {
      final authenticated = await _authenticate();
      if (!authenticated) {
        return;
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final nextScreen = settings.onboardingCompleted
        ? const HomeScreen()
        : const OnboardingReadinessScreen();

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => nextScreen));
  }

  Future<bool> _authenticate() async {
    final auth = LocalAuthentication();
    try {
      final canCheck = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (!canCheck) return true; // If device doesn't support, let them in

      return await auth.authenticate(
        localizedReason: 'Authenticate to open ${AppStrings.appName}',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_upload_rounded,
              size: 90,
              color: AppColors.primary,
            ),
            const SizedBox(height: 24),
            Text(
              AppStrings.appName,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.appVersion,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
