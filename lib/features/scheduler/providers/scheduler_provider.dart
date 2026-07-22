import 'dart:async';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backup/models/backup_job_model.dart';
import '../../backup/providers/backup_provider.dart';
import '../../ftp/models/ftp_server_model.dart';
import '../../ftp/providers/ftp_provider.dart';
import '../../settings/providers/app_settings_provider.dart';
import '../../sync/models/sync_rule_model.dart';
import '../../sync/providers/sync_rule_provider.dart';
import '../../sync/services/wifi_status_service.dart';
import '../services/android_background_scheduler_service.dart';
import '../services/android_instant_sync_service.dart';

/// ===============================================================
/// OpenBackup
/// File : scheduler_provider.dart
/// Version : 1.0.0
/// Description : In-app scheduler foundation for automatic sync rules.
/// ===============================================================

final schedulerProvider = Provider<SchedulerService>((ref) {
  final service = SchedulerService(ref);
  ref.listen(backupJobProvider, (_, _) {
    unawaited(service.reconfigureAutomaticWork());
  });
  ref.listen(syncRuleProvider, (_, _) {
    unawaited(service.reconfigureAutomaticWork());
  });
  ref.listen(appSettingsProvider, (_, _) {
    unawaited(service.reconfigureAutomaticWork());
  });
  ref.onDispose(service.dispose);
  return service;
});

class SchedulerService {
  SchedulerService(this._ref);

  static const Duration _tickInterval = Duration(minutes: 1);
  static const Duration _homeWifiMinimumInterval = Duration(minutes: 15);
  static const Duration _instantSyncDebounce = Duration(seconds: 5);

  final Ref _ref;
  final Set<String> _runningJobIds = {};
  final Set<String> _runningRuleIds = {};
  final Map<String, _InstantSyncWatcher> _instantWatchers = {};
  final Map<String, Timer> _instantDebounceTimers = {};
  Timer? _timer;
  bool _isTicking = false;

  Future<void> start() async {
    if (_timer != null) {
      return;
    }

    await _loadRepositories();
    await _configureAndroidBackgroundSchedule();
    await _configureInstantSyncWatchers();
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
      final settings = _ref.read(appSettingsProvider);
      if (!settings.automaticSchedulingEnabled) {
        await _cancelInstantSyncWatchers();
        await AndroidInstantSyncService.cancel();
        return;
      }

      await _configureInstantSyncWatchers();
      final ftpServers = _ref.read(ftpServerProvider);
      await _runDueBackupJobs(ftpServers);
      await _runDueSyncRules(ftpServers);
    } finally {
      _isTicking = false;
    }
  }

  Future<void> refreshBackgroundSchedule() async {
    await _loadRepositories();
    await reconfigureAutomaticWork();
  }

  Future<void> reconfigureAutomaticWork() async {
    await _configureAndroidBackgroundSchedule();
    await _configureInstantSyncWatchers();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    for (final timer in _instantDebounceTimers.values) {
      timer.cancel();
    }
    _instantDebounceTimers.clear();
    for (final watcher in _instantWatchers.values) {
      unawaited(watcher.subscription.cancel());
    }
    _instantWatchers.clear();
  }

  Future<void> _runDueBackupJobs(List<FtpServerModel> ftpServers) async {
    final jobs = _ref.read(backupJobProvider);
    for (final job in jobs) {
      if (!await _shouldRunBackupJob(job)) {
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
    await _ref.read(appSettingsProvider.notifier).loadSettings();
    await _ref.read(backupJobProvider.notifier).loadJobs();
    await _ref.read(ftpServerProvider.notifier).loadServers();
    await _ref.read(syncRuleProvider.notifier).loadRules();
  }

  Future<bool> _shouldRunBackupJob(BackupJobModel job) async {
    if (!job.enabled ||
        job.status == BackupJobStatus.running ||
        _runningJobIds.contains(job.id)) {
      return false;
    }

    if (job.runOnlyWhileCharging) {
      final battery = Battery();
      final state = await battery.batteryState;
      if (state != BatteryState.charging && state != BatteryState.full) {
        return false;
      }
    }

    return switch (job.scheduleRule) {
      BackupScheduleRule.manualOnly => false,
      BackupScheduleRule.instant => false,
      BackupScheduleRule.hourly => _isDue(
        job.lastRunAt,
        const Duration(hours: 1),
      ),
      BackupScheduleRule.daily => _isDue(
        job.lastRunAt,
        const Duration(days: 1),
      ),
      BackupScheduleRule.onHomeWifi => _isHomeWifiBackupDue(job),
    };
  }

  Future<bool> _shouldRunRule(SyncRuleModel rule) async {
    if (!rule.enabled ||
        rule.status == SyncRuleStatus.running ||
        _runningRuleIds.contains(rule.id)) {
      return false;
    }

    if (rule.runOnlyWhileCharging) {
      final battery = Battery();
      final state = await battery.batteryState;
      if (state != BatteryState.charging && state != BatteryState.full) {
        return false;
      }
    }

    return switch (rule.triggerRule) {
      SyncTriggerRule.manualOnly => false,
      SyncTriggerRule.instant => false,
      SyncTriggerRule.hourly => _isDue(
        rule.lastRunAt,
        const Duration(hours: 1),
      ),
      SyncTriggerRule.daily => _isDue(rule.lastRunAt, const Duration(days: 1)),
      SyncTriggerRule.onHomeWifi => _isHomeWifiRuleDue(rule),
    };
  }

  Future<void> _configureAndroidBackgroundSchedule() async {
    final settings = _ref.read(appSettingsProvider);
    if (!settings.automaticSchedulingEnabled) {
      await AndroidBackgroundSchedulerService.cancel();
      return;
    }

    final jobs = _ref.read(backupJobProvider);
    final rules = _ref.read(syncRuleProvider);
    final hasAutomaticWork =
        jobs.any(_isBackgroundJob) || rules.any(_isBackgroundRule);
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

  bool _isBackgroundJob(BackupJobModel job) {
    return _isAutomaticJob(job) &&
        job.scheduleRule != BackupScheduleRule.instant;
  }

  bool _isAutomaticRule(SyncRuleModel rule) {
    return rule.enabled && rule.triggerRule != SyncTriggerRule.manualOnly;
  }

  bool _isBackgroundRule(SyncRuleModel rule) {
    return _isAutomaticRule(rule) &&
        rule.triggerRule != SyncTriggerRule.instant;
  }

  int _backgroundIntervalMinutes(
    List<BackupJobModel> jobs,
    List<SyncRuleModel> rules,
  ) {
    final hasHomeWifiJobs = jobs.any(
      (job) => _isBackgroundJob(job) && job.homeWifiName.trim().isNotEmpty,
    );
    final hasHomeWifiRules = rules.any(
      (rule) =>
          _isBackgroundRule(rule) &&
          rule.triggerRule == SyncTriggerRule.onHomeWifi,
    );
    if (hasHomeWifiJobs || hasHomeWifiRules) {
      return _homeWifiMinimumInterval.inMinutes;
    }

    final hasHourlyJobs = jobs.any(
      (job) =>
          _isBackgroundJob(job) &&
          job.scheduleRule == BackupScheduleRule.hourly,
    );
    final hasHourlyRules = rules.any(
      (rule) =>
          _isBackgroundRule(rule) && rule.triggerRule == SyncTriggerRule.hourly,
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

  Future<bool> _isHomeWifiBackupDue(BackupJobModel job) async {
    final expectedSsid = job.homeWifiName.trim();
    if (expectedSsid.isEmpty ||
        !_isDue(job.lastRunAt, _homeWifiMinimumInterval)) {
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

  Future<void> _configureInstantSyncWatchers() async {
    final settings = _ref.read(appSettingsProvider);
    if (!settings.automaticSchedulingEnabled) {
      await _cancelInstantSyncWatchers();
      await AndroidInstantSyncService.cancel();
      return;
    }

    final instantJobs = _ref
        .read(backupJobProvider)
        .where(
          (job) =>
              job.enabled &&
              job.scheduleRule == BackupScheduleRule.instant &&
              job.localFolderPath.trim().isNotEmpty,
        )
        .toList();
    final instantRules = _ref
        .read(syncRuleProvider)
        .where(
          (rule) =>
              rule.enabled &&
              rule.triggerRule == SyncTriggerRule.instant &&
              rule.localFolderPath.trim().isNotEmpty,
        )
        .toList();

    if (Platform.isAndroid) {
      final configured = await AndroidInstantSyncService.configure(
        enabled: instantJobs.isNotEmpty || instantRules.isNotEmpty,
        localFolderPaths: [
          ...instantJobs.map((job) => job.localFolderPath.trim()),
          ...instantRules.map((rule) => rule.localFolderPath.trim()),
        ].where((path) => path.isNotEmpty).toSet().toList(growable: false),
      );
      if (configured) {
        await _cancelInstantSyncWatchers();
        return;
      }
    }

    final activeWatcherIds = {
      ...instantJobs.map((job) => _watcherId('backup', job.id)),
      ...instantRules.map((rule) => _watcherId('sync', rule.id)),
    };

    for (final watcher in _instantWatchers.values.toList()) {
      if (!activeWatcherIds.contains(watcher.id)) {
        await _cancelInstantSyncWatcher(watcher.id);
      }
    }

    for (final job in instantJobs) {
      final watcherId = _watcherId('backup', job.id);
      final existing = _instantWatchers[watcherId];
      if (existing != null && existing.localFolderPath == job.localFolderPath) {
        continue;
      }

      await _cancelInstantSyncWatcher(watcherId);
      await _startInstantBackupWatcher(job);
    }

    for (final rule in instantRules) {
      final watcherId = _watcherId('sync', rule.id);
      final existing = _instantWatchers[watcherId];
      if (existing != null &&
          existing.localFolderPath == rule.localFolderPath &&
          existing.recursive == rule.syncSubfolders) {
        continue;
      }

      await _cancelInstantSyncWatcher(watcherId);
      await _startInstantSyncWatcher(rule);
    }
  }

  Future<void> _startInstantBackupWatcher(BackupJobModel job) async {
    final directory = Directory(job.localFolderPath);
    if (!await directory.exists()) {
      return;
    }

    final watcherId = _watcherId('backup', job.id);
    final subscription = await _watchDirectory(
      directory: directory,
      recursive: true,
      watcherId: watcherId,
    );
    if (subscription == null) {
      return;
    }

    _instantWatchers[watcherId] = _InstantSyncWatcher(
      id: watcherId,
      localFolderPath: job.localFolderPath,
      recursive: true,
      subscription: subscription,
    );
  }

  Future<void> _startInstantSyncWatcher(SyncRuleModel rule) async {
    final directory = Directory(rule.localFolderPath);
    if (!await directory.exists()) {
      return;
    }

    final watcherId = _watcherId('sync', rule.id);
    final subscription = await _watchDirectory(
      directory: directory,
      recursive: rule.syncSubfolders,
      watcherId: watcherId,
    );
    if (subscription == null) {
      return;
    }

    _instantWatchers[watcherId] = _InstantSyncWatcher(
      id: watcherId,
      localFolderPath: rule.localFolderPath,
      recursive: rule.syncSubfolders,
      subscription: subscription,
    );
  }

  Future<StreamSubscription<FileSystemEvent>?> _watchDirectory({
    required Directory directory,
    required bool recursive,
    required String watcherId,
  }) async {
    try {
      return directory
          .watch(recursive: recursive)
          .listen(
            (_) => _scheduleInstantSync(watcherId),
            onError: (_) {
              unawaited(_cancelInstantSyncWatcher(watcherId));
            },
          );
    } on FileSystemException {
      if (!recursive) {
        return null;
      }

      try {
        return directory.watch().listen(
          (_) => _scheduleInstantSync(watcherId),
          onError: (_) {
            unawaited(_cancelInstantSyncWatcher(watcherId));
          },
        );
      } on FileSystemException {
        return null;
      }
    }
  }

  void _scheduleInstantSync(String watcherId) {
    _instantDebounceTimers[watcherId]?.cancel();
    _instantDebounceTimers[watcherId] = Timer(_instantSyncDebounce, () {
      _instantDebounceTimers.remove(watcherId);
      if (watcherId.startsWith('backup:')) {
        unawaited(_runInstantBackupJob(watcherId.substring('backup:'.length)));
      } else if (watcherId.startsWith('sync:')) {
        unawaited(_runInstantSyncRule(watcherId.substring('sync:'.length)));
      }
    });
  }

  Future<void> _runInstantBackupJob(String jobId) async {
    if (_runningJobIds.contains(jobId)) {
      return;
    }

    await _loadRepositories();
    final jobs = _ref.read(backupJobProvider);
    BackupJobModel? job;
    for (final item in jobs) {
      if (item.id == jobId) {
        job = item;
        break;
      }
    }

    if (job == null ||
        !job.enabled ||
        job.scheduleRule != BackupScheduleRule.instant ||
        job.status == BackupJobStatus.running) {
      return;
    }

    final ftpServer = _findFtpServer(
      _ref.read(ftpServerProvider),
      job.ftpServerId,
    );
    if (ftpServer == null) {
      return;
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

  Future<void> _runInstantSyncRule(String ruleId) async {
    if (_runningRuleIds.contains(ruleId)) {
      return;
    }

    await _loadRepositories();
    final rules = _ref.read(syncRuleProvider);
    SyncRuleModel? rule;
    for (final item in rules) {
      if (item.id == ruleId) {
        rule = item;
        break;
      }
    }

    if (rule == null ||
        !rule.enabled ||
        rule.triggerRule != SyncTriggerRule.instant ||
        rule.status == SyncRuleStatus.running) {
      return;
    }

    final ftpServer = _findFtpServer(
      _ref.read(ftpServerProvider),
      rule.ftpServerId,
    );
    if (ftpServer == null) {
      return;
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

  Future<void> _cancelInstantSyncWatcher(String ruleId) async {
    _instantDebounceTimers.remove(ruleId)?.cancel();
    final watcher = _instantWatchers.remove(ruleId);
    if (watcher != null) {
      await watcher.subscription.cancel();
    }
  }

  Future<void> _cancelInstantSyncWatchers() async {
    for (final timer in _instantDebounceTimers.values) {
      timer.cancel();
    }
    _instantDebounceTimers.clear();

    for (final watcher in _instantWatchers.values.toList()) {
      await watcher.subscription.cancel();
    }
    _instantWatchers.clear();
  }

  String _watcherId(String kind, String id) {
    return '$kind:$id';
  }
}

class _InstantSyncWatcher {
  final String id;
  final String localFolderPath;
  final bool recursive;
  final StreamSubscription<FileSystemEvent> subscription;

  const _InstantSyncWatcher({
    required this.id,
    required this.localFolderPath,
    required this.recursive,
    required this.subscription,
  });
}
