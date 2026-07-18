import 'package:connectivity_plus/connectivity_plus.dart';

import '../../ftp/models/ftp_server_model.dart';
import '../../history/models/history_entry_model.dart';
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
  final int checkedRules;
  final int executedRules;
  final int failedRules;

  const HeadlessScheduledSyncResult({
    required this.checkedRules,
    required this.executedRules,
    required this.failedRules,
  });

  String get message {
    if (executedRules == 0) {
      return 'No scheduled sync rules were due.';
    }

    if (failedRules == 0) {
      return 'Ran $executedRules scheduled sync rule(s).';
    }

    return 'Ran $executedRules scheduled sync rule(s), $failedRules failed.';
  }
}

class HeadlessScheduledSyncRunner {
  static const Duration _homeWifiMinimumInterval = Duration(minutes: 15);

  final FtpMemoryRepository _ftpRepository = FtpMemoryRepository.instance;
  final SyncRuleRepository _syncRepository = SyncRuleRepository.instance;
  final HistoryRepository _historyRepository = HistoryRepository.instance;

  Future<HeadlessScheduledSyncResult> runDueSyncRules() async {
    await _ftpRepository.load();
    await _syncRepository.load();
    await _historyRepository.load();

    final ftpServers = _ftpRepository.getAll();
    final rules = _syncRepository.getAll();
    var checkedRules = 0;
    var executedRules = 0;
    var failedRules = 0;

    for (final rule in rules) {
      if (rule.triggerRule == SyncTriggerRule.manualOnly) {
        continue;
      }

      checkedRules += 1;
      if (!await _shouldRunRule(rule)) {
        continue;
      }

      final ftpServer = _findFtpServer(ftpServers, rule.ftpServerId);
      if (ftpServer == null) {
        await _recordMissingServer(rule);
        failedRules += 1;
        continue;
      }

      executedRules += 1;
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
        failedRules += 1;
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

    await _syncRepository.flush();
    await _historyRepository.flush();

    return HeadlessScheduledSyncResult(
      checkedRules: checkedRules,
      executedRules: executedRules,
      failedRules: failedRules,
    );
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

  FtpServerModel? _findFtpServer(List<FtpServerModel> servers, String id) {
    for (final server in servers) {
      if (server.id == id) {
        return server;
      }
    }

    return null;
  }
}
