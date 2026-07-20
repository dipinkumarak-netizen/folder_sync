import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/models/transfer_progress_snapshot.dart';
import '../../../core/utils/failure_message.dart';
import '../../ftp/models/ftp_server_model.dart';
import '../../history/models/history_entry_model.dart';
import '../../history/providers/history_provider.dart';
import '../../repositories/backup_memory_repository.dart';
import '../../settings/models/app_settings_model.dart';
import '../../settings/providers/app_settings_provider.dart';
import '../../sync/services/wifi_status_service.dart';
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

final backupTransferProgressProvider = StateProvider<TransferProgressSnapshot?>(
  (ref) => null,
);

class BackupJobNotifier extends StateNotifier<List<BackupJobModel>> {
  BackupJobNotifier(
    this._repository,
    this._historyNotifier,
    this._progressController,
    this._readSettings,
  ) : super(_repository.getAll().toList());

  final BackupMemoryRepository _repository;
  final HistoryNotifier _historyNotifier;
  final StateController<TransferProgressSnapshot?> _progressController;
  final AppSettingsModel Function() _readSettings;
  DateTime? _progressStartedAt;

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
    if (!job.enabled) {
      return BackupRunResult(
        success: false,
        message: 'Enable this job before running it.',
        filesBackedUp: 0,
        bytesBackedUp: 0,
        backedUpRelativePaths: job.backedUpRelativePaths,
      );
    }

    final networkCheck = await _checkNetworkPolicy(job);
    if (!networkCheck.success) {
      final failedJob = _completeJob(job, networkCheck);
      _repository.update(failedJob);
      await _writeHistory(failedJob, ftpServer, networkCheck);
      refresh();
      return networkCheck;
    }

    final runningJob = job.copyWith(
      status: BackupJobStatus.running,
      lastMessage: 'Backup is running...',
    );
    _repository.update(runningJob);
    final startedAt = DateTime.now();
    _progressStartedAt = startedAt;
    _setTransferProgress(
      title: 'Backup Progress',
      status: 'Preparing backup files...',
      currentFilePath: '',
      processedFiles: 0,
      totalFiles: 0,
      processedBytes: 0,
      startedAt: startedAt,
      active: true,
    );
    refresh();

    var foregroundStarted = false;
    if (_readSettings().showForegroundNotifications) {
      foregroundStarted = await BackupForegroundServiceBridge.start(
        message: 'Preparing backup...',
      );
    }

    BackupRunResult result;
    try {
      result = await _repository.runBackup(
        job: runningJob,
        ftpServer: ftpServer,
        onProgress: (progress) async {
          final snapshot = _setTransferProgress(
            title: 'Backup Progress',
            status: 'Uploading files to ${ftpServer.name}',
            currentFilePath: progress.currentFilePath,
            processedFiles: progress.currentFileIndex,
            totalFiles: progress.totalFiles,
            processedBytes: progress.bytesBackedUp,
            startedAt: _progressStartedAt ?? startedAt,
            active: true,
          );
          if (foregroundStarted) {
            await BackupForegroundServiceBridge.update(
              message: snapshot.notificationMessage(),
            );
          }
        },
      );
    } catch (error) {
      result = BackupRunResult(
        success: false,
        message: FailureMessage.from(
          error,
          operation: 'Backup',
          fallback: 'Backup failed unexpectedly.',
        ),
        filesBackedUp: 0,
        bytesBackedUp: 0,
        backedUpRelativePaths: runningJob.backedUpRelativePaths,
      );
    } finally {
      if (foregroundStarted) {
        await BackupForegroundServiceBridge.stop();
      }
    }

    final completedJob = _completeJob(runningJob, result);
    _repository.update(completedJob);
    await _writeHistory(completedJob, ftpServer, result);
    refresh();
    _setTransferProgress(
      title: 'Backup Progress',
      status: result.message,
      currentFilePath: '',
      processedFiles: result.filesBackedUp,
      totalFiles: result.filesBackedUp,
      processedBytes: result.bytesBackedUp,
      startedAt: _progressStartedAt ?? startedAt,
      active: false,
    );
    _progressStartedAt = null;

    return result;
  }

  TransferProgressSnapshot _setTransferProgress({
    required String title,
    required String status,
    required String currentFilePath,
    required int processedFiles,
    required int totalFiles,
    required int processedBytes,
    required DateTime startedAt,
    required bool active,
  }) {
    final snapshot = TransferProgressSnapshot(
      title: title,
      status: status,
      currentFilePath: currentFilePath,
      processedFiles: processedFiles,
      totalFiles: totalFiles,
      processedBytes: processedBytes,
      startedAt: startedAt,
      updatedAt: DateTime.now(),
      active: active,
    );
    _progressController.state = snapshot;
    return snapshot;
  }

  BackupJobModel _completeJob(BackupJobModel job, BackupRunResult result) {
    return job.copyWith(
      status: result.success ? BackupJobStatus.success : BackupJobStatus.failed,
      lastRunAt: DateTime.now(),
      lastMessage: result.message,
      lastFilesBackedUp: result.filesBackedUp,
      totalFilesBackedUp: job.totalFilesBackedUp + result.filesBackedUp,
      totalBytesBackedUp: job.totalBytesBackedUp + result.bytesBackedUp,
      backedUpRelativePaths: result.backedUpRelativePaths,
    );
  }

  Future<BackupRunResult> _checkNetworkPolicy(BackupJobModel job) async {
    if (!job.runOnWifiOnly && job.homeWifiName.trim().isEmpty) {
      return BackupRunResult(
        success: true,
        message: '',
        filesBackedUp: 0,
        bytesBackedUp: 0,
        backedUpRelativePaths: job.backedUpRelativePaths,
      );
    }

    final connectivity = await Connectivity().checkConnectivity();
    final isWifi = connectivity.contains(ConnectivityResult.wifi);
    if (!isWifi) {
      return BackupRunResult(
        success: false,
        message: 'Backup skipped because Wi-Fi is not connected.',
        filesBackedUp: 0,
        bytesBackedUp: 0,
        backedUpRelativePaths: job.backedUpRelativePaths,
      );
    }

    final expectedSsid = job.homeWifiName.trim();
    if (expectedSsid.isEmpty) {
      return BackupRunResult(
        success: true,
        message: '',
        filesBackedUp: 0,
        bytesBackedUp: 0,
        backedUpRelativePaths: job.backedUpRelativePaths,
      );
    }

    final hasWifiPermission = await _requestWifiNamePermissions();
    if (!hasWifiPermission) {
      return BackupRunResult(
        success: false,
        message:
            'Backup skipped because Wi-Fi name permission was not granted.',
        filesBackedUp: 0,
        bytesBackedUp: 0,
        backedUpRelativePaths: job.backedUpRelativePaths,
      );
    }

    final currentSsid = await WifiStatusService.currentSsid();
    if (currentSsid == null) {
      return BackupRunResult(
        success: false,
        message:
            'Backup skipped because the current Wi-Fi name is unavailable.',
        filesBackedUp: 0,
        bytesBackedUp: 0,
        backedUpRelativePaths: job.backedUpRelativePaths,
      );
    }

    if (currentSsid != expectedSsid) {
      return BackupRunResult(
        success: false,
        message: 'Backup skipped because Wi-Fi is "$currentSsid".',
        filesBackedUp: 0,
        bytesBackedUp: 0,
        backedUpRelativePaths: job.backedUpRelativePaths,
      );
    }

    return BackupRunResult(
      success: true,
      message: '',
      filesBackedUp: 0,
      bytesBackedUp: 0,
      backedUpRelativePaths: job.backedUpRelativePaths,
    );
  }

  Future<bool> _requestWifiNamePermissions() async {
    final nearbyStatus = await Permission.nearbyWifiDevices.request();
    final locationStatus = await Permission.locationWhenInUse.request();
    return nearbyStatus.isGranted || locationStatus.isGranted;
  }

  Future<void> _writeHistory(
    BackupJobModel job,
    FtpServerModel ftpServer,
    BackupRunResult result,
  ) async {
    await _historyNotifier.addEntry(
      HistoryEntryModel(
        id: '${job.id}-${DateTime.now().microsecondsSinceEpoch}',
        operationType: HistoryOperationType.backup,
        status: result.success
            ? HistoryEntryStatus.success
            : HistoryEntryStatus.failed,
        title: job.name,
        message: result.message,
        sourcePath: job.localFolderPath,
        targetPath: '${ftpServer.name}:${job.remoteFolderPath}',
        relatedId: job.id,
        createdAt: DateTime.now(),
        filesChanged: result.filesBackedUp,
        bytesChanged: result.bytesBackedUp,
        fileReports: result.runBackedUpRelativePaths
            .map(
              (relativePath) => HistoryFileReportItem(
                relativePath: relativePath,
                action: 'upload',
              ),
            )
            .toList(),
      ),
    );
  }
}

final backupJobProvider =
    StateNotifierProvider<BackupJobNotifier, List<BackupJobModel>>((ref) {
      final repository = ref.watch(backupRepositoryProvider);
      final historyNotifier = ref.watch(historyProvider.notifier);
      final progressController = ref.watch(
        backupTransferProgressProvider.notifier,
      );
      return BackupJobNotifier(
        repository,
        historyNotifier,
        progressController,
        () => ref.read(appSettingsProvider),
      );
    });

final backupJobLoadProvider = FutureProvider<void>((ref) async {
  await ref.read(backupJobProvider.notifier).loadJobs();
});
