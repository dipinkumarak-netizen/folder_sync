import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ftp/models/ftp_server_model.dart';
import '../../repositories/backup_memory_repository.dart';
import '../models/backup_job_model.dart';
import '../services/backup_foreground_service.dart';

/// ===============================================================
/// OpenBackup
/// File : backup_provider.dart
/// Version : 1.0.0
/// Description : Riverpod provider for backup jobs.
/// ===============================================================

final backupRepositoryProvider = Provider<BackupMemoryRepository>((ref) {
  return BackupMemoryRepository.instance;
});

class BackupJobNotifier extends StateNotifier<List<BackupJobModel>> {
  BackupJobNotifier(this._repository) : super(_repository.getAll().toList());

  final BackupMemoryRepository _repository;

  void refresh() {
    state = _repository.getAll().toList();
  }

  Future<void> loadJobs() async {
    await _repository.load();
    refresh();
  }

  Future<void> addJob(BackupJobModel job) async {
    _repository.add(job);
    refresh();
  }

  Future<void> updateJob(BackupJobModel job) async {
    _repository.update(job);
    refresh();
  }

  Future<void> deleteJob(String id) async {
    _repository.remove(id);
    refresh();
  }

  Future<void> toggleJob(String id, bool enabled) async {
    final job = _repository.findById(id);
    if (job == null) {
      return;
    }

    _repository.update(job.copyWith(enabled: enabled));
    refresh();
  }

  Future<BackupRunResult> runJob({
    required BackupJobModel job,
    required FtpServerModel ftpServer,
  }) async {
    final runningJob = job.copyWith(
      status: BackupJobStatus.running,
      lastMessage: 'Backup is running...',
    );
    _repository.update(runningJob);
    refresh();

    await BackupForegroundServiceBridge.start();

    BackupRunResult result;
    try {
      result = await _repository.runBackup(
        job: runningJob,
        ftpServer: ftpServer,
      );
    } catch (_) {
      result = BackupRunResult(
        success: false,
        message: 'Backup failed unexpectedly.',
        filesBackedUp: 0,
        bytesBackedUp: 0,
        backedUpRelativePaths: runningJob.backedUpRelativePaths,
      );
    } finally {
      await BackupForegroundServiceBridge.stop();
    }

    final completedJob = runningJob.copyWith(
      status: result.success ? BackupJobStatus.success : BackupJobStatus.failed,
      lastRunAt: DateTime.now(),
      lastMessage: result.message,
      lastFilesBackedUp: result.filesBackedUp,
      totalFilesBackedUp: runningJob.totalFilesBackedUp + result.filesBackedUp,
      totalBytesBackedUp: runningJob.totalBytesBackedUp + result.bytesBackedUp,
      backedUpRelativePaths: result.backedUpRelativePaths,
    );

    _repository.update(completedJob);
    refresh();

    return result;
  }
}

final backupJobProvider =
    StateNotifierProvider<BackupJobNotifier, List<BackupJobModel>>((ref) {
      final repository = ref.watch(backupRepositoryProvider);
      return BackupJobNotifier(repository);
    });

final backupJobLoadProvider = FutureProvider<void>((ref) async {
  await ref.read(backupJobProvider.notifier).loadJobs();
});
