import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/scheduler/providers/scheduler_provider.dart';
import 'screens/splash/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const FtpBackupApp());
}

class FtpBackupApp extends StatelessWidget {
  const FtpBackupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: _SchedulerBootstrap());
  }
}

class _SchedulerBootstrap extends ConsumerStatefulWidget {
  const _SchedulerBootstrap();

  @override
  ConsumerState<_SchedulerBootstrap> createState() =>
      _SchedulerBootstrapState();
}

class _SchedulerBootstrapState extends ConsumerState<_SchedulerBootstrap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(schedulerProvider).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FTP Backup',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.darkTheme,

      home: const SplashScreen(),
    );
  }
}
