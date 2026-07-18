import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backup/models/backup_job_model.dart';
import '../../backup/providers/backup_provider.dart';
import '../../ftp/models/ftp_server_model.dart';
import '../../ftp/providers/ftp_provider.dart';
import '../../sync/models/sync_rule_model.dart';
import '../../sync/providers/sync_rule_provider.dart';
import '../../sync/services/wifi_status_service.dart';
import '../services/android_background_scheduler_service.dart';

/// ===============================================================
/// OpenBackup
/// File : scheduler_provider.dart
/// Version : 1.0.0
/// Description : In-app scheduler foundation for automatic sync rules.
/// ===============================================================

final schedulerProvider = Provider<SchedulerService>((ref) {
  final service = SchedulerService(ref);
  ref.onDispose(service.dispose);
  return service;
});

class SchedulerService {
  SchedulerService(this._ref);

  static const Duration _tickInterval = Duration(minutes: 1);
  static const Duration _homeWifiMinimumInterval = Duration(minutes: 15);

  final Ref _ref;
  final Set<String> _runningJobIds = {};
  final Set<String> _runningRuleIds = {};
  Timer? _timer;
  bool _isTicking = false;

  Future<void> start() async {
    if (_timer != null) {
      return;
    }

    await _loadRepositories();
    await _configureAndroidBackgroundSchedule();
    unawaited(runDueSyncRules());
    _timer = Timer.periodic(_tickInterval, (_) {
      unawaited(runDueSyncRules());
    });
  }

  Future<void> runDueSyncRules() async {
    if (_isTicking) {
      return;
    }

    _isTicking = true;
    try {
      await _loadRepositories();
      await _configureAndroidBackgroundSchedule();

      final ftpServers = _ref.read(ftpServerProvider);
      await _runDueBackupJobs(ftpServers);
      await _runDueSyncRules(ftpServers);
    } finally {
      _isTicking = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _runDueBackupJobs(List<FtpServerModel> ftpServers) async {
    final jobs = _ref.read(backupJobProvider);
    for (final job in jobs) {
      if (!_shouldRunBackupJob(job)) {
        continue;
      }

      final ftpServer = _findFtpServer(ftpServers, job.ftpServerId);
      if (ftpServer == null) {
        continue;
      }

      _runningJobIds.add(job.id);
      try {
        await _ref
            .read(backupJobProvider.notifier)
            .runJob(job: job, ftpServer: ftpServer);
      } finally {
        _runningJobIds.remove(job.id);
      }
    }
  }

  Future<void> _runDueSyncRules(List<FtpServerModel> ftpServers) async {
    final rules = _ref.read(syncRuleProvider);
    for (final rule in rules) {
      if (!await _shouldRunRule(rule)) {
        continue;
      }

      final ftpServer = _findFtpServer(ftpServers, rule.ftpServerId);
      if (ftpServer == null) {
        continue;
      }

      _runningRuleIds.add(rule.id);
      try {
        await _ref
            .read(syncRuleProvider.notifier)
            .runRule(rule: rule, ftpServer: ftpServer);
      } finally {
        _runningRuleIds.remove(rule.id);
      }
    }
  }

  Future<void> _loadRepositories() async {
    await _ref.read(backupJobProvider.notifier).loadJobs();
    await _ref.read(ftpServerProvider.notifier).loadServers();
    await _ref.read(syncRuleProvider.notifier).loadRules();
  }

  bool _shouldRunBackupJob(BackupJobModel job) {
    if (!job.enabled ||
        job.status == BackupJobStatus.running ||
        _runningJobIds.contains(job.id)) {
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

  Future<bool> _shouldRunRule(SyncRuleModel rule) async {
    if (!rule.enabled ||
        rule.status == SyncRuleStatus.running ||
        _runningRuleIds.contains(rule.id)) {
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

  Future<void> _configureAndroidBackgroundSchedule() async {
    final jobs = _ref.read(backupJobProvider);
    final rules = _ref.read(syncRuleProvider);
    final hasAutomaticWork =
        jobs.any(_isAutomaticJob) || rules.any(_isAutomaticRule);
    if (!hasAutomaticWork) {
      await AndroidBackgroundSchedulerService.cancel();
      return;
    }

    await AndroidBackgroundSchedulerService.configure(
      enabled: true,
      intervalMinutes: _backgroundIntervalMinutes(jobs, rules),
    );
  }

  bool _isAutomaticJob(BackupJobModel job) {
    return job.enabled && job.scheduleRule != BackupScheduleRule.manualOnly;
  }

  bool _isAutomaticRule(SyncRuleModel rule) {
    return rule.enabled && rule.triggerRule != SyncTriggerRule.manualOnly;
  }

  int _backgroundIntervalMinutes(
    List<BackupJobModel> jobs,
    List<SyncRuleModel> rules,
  ) {
    final hasHomeWifiRules = rules.any(
      (rule) =>
          _isAutomaticRule(rule) &&
          rule.triggerRule == SyncTriggerRule.onHomeWifi,
    );
    if (hasHomeWifiRules) {
      return _homeWifiMinimumInterval.inMinutes;
    }

    final hasHourlyJobs = jobs.any(
      (job) =>
          _isAutomaticJob(job) && job.scheduleRule == BackupScheduleRule.hourly,
    );
    final hasHourlyRules = rules.any(
      (rule) =>
          _isAutomaticRule(rule) && rule.triggerRule == SyncTriggerRule.hourly,
    );
    if (hasHourlyJobs) {
      return 60;
    }

    return hasHourlyRules ? 60 : const Duration(days: 1).inMinutes;
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

  FtpServerModel? _findFtpServer(List<FtpServerModel> servers, String id) {
    for (final server in servers) {
      if (server.id == id) {
        return server;
      }
    }

    return null;
  }
}
