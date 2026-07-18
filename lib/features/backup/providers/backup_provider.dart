import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ftp/models/ftp_server_model.dart';
import '../../repositories/backup_memory_repository.dart';
import '../models/backup_job_model.dart';

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

  void addJob(BackupJobModel job) {
    _repository.add(job);
    refresh();
  }

  void updateJob(BackupJobModel job) {
    _repository.update(job);
    refresh();
  }

  void deleteJob(String id) {
    _repository.remove(id);
    refresh();
  }

  void toggleJob(String id, bool enabled) {
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

    final result = await _repository.runBackup(
      job: runningJob,
      ftpServer: ftpServer,
    );

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
