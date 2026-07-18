import 'package:connectivity_plus/connectivity_plus.dart';

import '../../backup/models/backup_job_model.dart';
import '../../ftp/models/ftp_server_model.dart';
import '../../history/models/history_entry_model.dart';
import '../../repositories/backup_memory_repository.dart';
import '../../repositories/ftp_memory_repository.dart';
import '../../repositories/history_repository.dart';
import '../../repositories/sync_rule_repository.dart';
import '../../sync/models/sync_rule_model.dart';
import '../../sync/services/wifi_status_service.dart';

/// ===============================================================
/// OpenBackup
/// File : headless_scheduled_sync_runner.dart
/// Version : 1.0.0
/// Description : Runs due scheduled sync rules without the Flutter UI.
/// ===============================================================

class HeadlessScheduledSyncResult {
  final int checkedJobs;
  final int executedJobs;
  final int failedJobs;
  final int checkedSyncRules;
  final int executedSyncRules;
  final int failedSyncRules;

  const HeadlessScheduledSyncResult({
    required this.checkedJobs,
    required this.executedJobs,
    required this.failedJobs,
    required this.checkedSyncRules,
    required this.executedSyncRules,
    required this.failedSyncRules,
  });

  String get message {
    final executedTotal = executedJobs + executedSyncRules;
    final failedTotal = failedJobs + failedSyncRules;
    if (executedTotal == 0) {
      return 'No scheduled work was due.';
    }

    if (failedTotal == 0) {
      return 'Ran $executedTotal scheduled task(s).';
    }

    return 'Ran $executedTotal scheduled task(s), $failedTotal failed.';
  }
}

class HeadlessScheduledSyncRunner {
  static const Duration _homeWifiMinimumInterval = Duration(minutes: 15);

  final BackupMemoryRepository _backupRepository =
      BackupMemoryRepository.instance;
  final FtpMemoryRepository _ftpRepository = FtpMemoryRepository.instance;
  final SyncRuleRepository _syncRepository = SyncRuleRepository.instance;
  final HistoryRepository _historyRepository = HistoryRepository.instance;

  Future<HeadlessScheduledSyncResult> runDueSyncRules() async {
    await _backupRepository.load();
    await _ftpRepository.load();
    await _syncRepository.load();
    await _historyRepository.load();

    final ftpServers = _ftpRepository.getAll();
    final rules = _syncRepository.getAll();
    var checkedJobs = 0;
    var executedJobs = 0;
    var failedJobs = 0;
    var checkedSyncRules = 0;
    var executedSyncRules = 0;
    var failedSyncRules = 0;

    for (final job in _backupRepository.getAll()) {
      if (job.scheduleRule == BackupScheduleRule.manualOnly) {
        continue;
      }

      checkedJobs += 1;
      if (!_shouldRunBackupJob(job)) {
        continue;
      }

      if (!await _checkBackupNetworkPolicy(job)) {
        continue;
      }

      final ftpServer = _findFtpServer(ftpServers, job.ftpServerId);
      if (ftpServer == null) {
        await _recordMissingBackupServer(job);
        failedJobs += 1;
        continue;
      }

      executedJobs += 1;
      final runningJob = job.copyWith(
        status: BackupJobStatus.running,
        lastMessage: 'Scheduled backup is running...',
      );
      _backupRepository.update(runningJob);

      final result = await _backupRepository.runBackup(
        job: runningJob,
        ftpServer: ftpServer,
      );
      if (!result.success) {
        failedJobs += 1;
      }

      final completedJob = runningJob.copyWith(
        status: result.success
            ? BackupJobStatus.success
            : BackupJobStatus.failed,
        lastRunAt: DateTime.now(),
        lastMessage: result.message,
        lastFilesBackedUp: result.filesBackedUp,
        totalFilesBackedUp:
            runningJob.totalFilesBackedUp + result.filesBackedUp,
        totalBytesBackedUp:
            runningJob.totalBytesBackedUp + result.bytesBackedUp,
        backedUpRelativePaths: result.backedUpRelativePaths,
      );
      _backupRepository.update(completedJob);
      _historyRepository.add(
        HistoryEntryModel(
          id: '${completedJob.id}-${DateTime.now().microsecondsSinceEpoch}',
          operationType: HistoryOperationType.backup,
          status: result.success
              ? HistoryEntryStatus.success
              : HistoryEntryStatus.failed,
          title: completedJob.name,
          message: result.message,
          sourcePath: completedJob.localFolderPath,
          targetPath: '${ftpServer.name}:${completedJob.remoteFolderPath}',
          relatedId: completedJob.id,
          createdAt: DateTime.now(),
          filesChanged: result.filesBackedUp,
          bytesChanged: result.bytesBackedUp,
        ),
      );
    }

    for (final rule in rules) {
      if (rule.triggerRule == SyncTriggerRule.manualOnly) {
        continue;
      }

      checkedSyncRules += 1;
      if (!await _shouldRunRule(rule)) {
        continue;
      }

      final ftpServer = _findFtpServer(ftpServers, rule.ftpServerId);
      if (ftpServer == null) {
        await _recordMissingServer(rule);
        failedSyncRules += 1;
        continue;
      }

      executedSyncRules += 1;
      final runningRule = rule.copyWith(
        status: SyncRuleStatus.running,
        lastMessage: 'Scheduled synchronization is running...',
      );
      _syncRepository.update(runningRule);

      final result = await _syncRepository.runSync(
        rule: runningRule,
        ftpServer: ftpServer,
      );
      if (!result.success) {
        failedSyncRules += 1;
      }

      final completedRule = runningRule.copyWith(
        status: result.success ? SyncRuleStatus.success : SyncRuleStatus.failed,
        lastRunAt: DateTime.now(),
        lastMessage: result.message,
        lastFilesChanged: result.filesChanged,
        totalFilesChanged: runningRule.totalFilesChanged + result.filesChanged,
        totalBytesChanged: runningRule.totalBytesChanged + result.bytesChanged,
      );
      _syncRepository.update(completedRule);
      _historyRepository.add(
        HistoryEntryModel(
          id: '${completedRule.id}-${DateTime.now().microsecondsSinceEpoch}',
          operationType: HistoryOperationType.sync,
          status: result.success
              ? HistoryEntryStatus.success
              : HistoryEntryStatus.failed,
          title: completedRule.name,
          message: result.message,
          sourcePath: completedRule.localFolderPath,
          targetPath: '${ftpServer.name}:${completedRule.remoteFolderPath}',
          relatedId: completedRule.id,
          createdAt: DateTime.now(),
          filesChanged: result.filesChanged,
          bytesChanged: result.bytesChanged,
        ),
      );
    }

    await _backupRepository.flush();
    await _syncRepository.flush();
    await _historyRepository.flush();

    return HeadlessScheduledSyncResult(
      checkedJobs: checkedJobs,
      executedJobs: executedJobs,
      failedJobs: failedJobs,
      checkedSyncRules: checkedSyncRules,
      executedSyncRules: executedSyncRules,
      failedSyncRules: failedSyncRules,
    );
  }

  bool _shouldRunBackupJob(BackupJobModel job) {
    if (!job.enabled || job.status == BackupJobStatus.running) {
      return false;
    }

    return switch (job.scheduleRule) {
      BackupScheduleRule.manualOnly => false,
      BackupScheduleRule.hourly => _isDue(
        job.lastRunAt,
        const Duration(hours: 1),
      ),
      BackupScheduleRule.daily => _isDue(
        job.lastRunAt,
        const Duration(days: 1),
      ),
    };
  }

  Future<bool> _checkBackupNetworkPolicy(BackupJobModel job) async {
    if (!job.runOnWifiOnly && job.homeWifiName.trim().isEmpty) {
      return true;
    }

    final connectivity = await Connectivity().checkConnectivity();
    if (!connectivity.contains(ConnectivityResult.wifi)) {
      return false;
    }

    final expectedSsid = job.homeWifiName.trim();
    if (expectedSsid.isEmpty) {
      return true;
    }

    final currentSsid = await WifiStatusService.currentSsid();
    return currentSsid == expectedSsid;
  }

  Future<bool> _shouldRunRule(SyncRuleModel rule) async {
    if (!rule.enabled || rule.status == SyncRuleStatus.running) {
      return false;
    }

    if (!await _checkNetworkPolicy(rule)) {
      return false;
    }

    return switch (rule.triggerRule) {
      SyncTriggerRule.manualOnly => false,
      SyncTriggerRule.hourly => _isDue(
        rule.lastRunAt,
        const Duration(hours: 1),
      ),
      SyncTriggerRule.daily => _isDue(rule.lastRunAt, const Duration(days: 1)),
      SyncTriggerRule.onHomeWifi => _isHomeWifiRuleDue(rule),
    };
  }

  Future<bool> _checkNetworkPolicy(SyncRuleModel rule) async {
    if (!rule.runOnWifiOnly && rule.homeWifiName.trim().isEmpty) {
      return true;
    }

    final connectivity = await Connectivity().checkConnectivity();
    if (!connectivity.contains(ConnectivityResult.wifi)) {
      return false;
    }

    return true;
  }

  Future<bool> _isHomeWifiRuleDue(SyncRuleModel rule) async {
    final expectedSsid = rule.homeWifiName.trim();
    if (expectedSsid.isEmpty ||
        !_isDue(rule.lastRunAt, _homeWifiMinimumInterval)) {
      return false;
    }

    final currentSsid = await WifiStatusService.currentSsid();
    return currentSsid == expectedSsid;
  }

  bool _isDue(DateTime? lastRunAt, Duration interval) {
    if (lastRunAt == null) {
      return true;
    }

    return DateTime.now().difference(lastRunAt) >= interval;
  }

  Future<void> _recordMissingServer(SyncRuleModel rule) async {
    final failedRule = rule.copyWith(
      status: SyncRuleStatus.failed,
      lastRunAt: DateTime.now(),
      lastMessage: 'Scheduled sync skipped because FTP server is missing.',
      lastFilesChanged: 0,
    );
    _syncRepository.update(failedRule);
    _historyRepository.add(
      HistoryEntryModel(
        id: '${failedRule.id}-${DateTime.now().microsecondsSinceEpoch}',
        operationType: HistoryOperationType.sync,
        status: HistoryEntryStatus.failed,
        title: failedRule.name,
        message: failedRule.lastMessage,
        sourcePath: failedRule.localFolderPath,
        targetPath: failedRule.remoteFolderPath,
        relatedId: failedRule.id,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> _recordMissingBackupServer(BackupJobModel job) async {
    final failedJob = job.copyWith(
      status: BackupJobStatus.failed,
      lastRunAt: DateTime.now(),
      lastMessage: 'Scheduled backup skipped because FTP server is missing.',
      lastFilesBackedUp: 0,
    );
    _backupRepository.update(failedJob);
    _historyRepository.add(
      HistoryEntryModel(
        id: '${failedJob.id}-${DateTime.now().microsecondsSinceEpoch}',
        operationType: HistoryOperationType.backup,
        status: HistoryEntryStatus.failed,
        title: failedJob.name,
        message: failedJob.lastMessage,
        sourcePath: failedJob.localFolderPath,
        targetPath: failedJob.remoteFolderPath,
        relatedId: failedJob.id,
        createdAt: DateTime.now(),
      ),
    );
  }

  FtpServerModel? _findFtpServer(List<FtpServerModel> servers, String id) {
    for (final server in servers) {
      if (server.id == id) {
        return server;
      }
    }

    return null;
  }
}
