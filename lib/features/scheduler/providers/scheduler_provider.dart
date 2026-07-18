import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ftp/models/ftp_server_model.dart';
import '../../ftp/providers/ftp_provider.dart';
import '../../sync/models/sync_rule_model.dart';
import '../../sync/providers/sync_rule_provider.dart';
import '../../sync/services/wifi_status_service.dart';

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
  final Set<String> _runningRuleIds = {};
  Timer? _timer;
  bool _isTicking = false;

  Future<void> start() async {
    if (_timer != null) {
      return;
    }

    await _loadRepositories();
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

      final ftpServers = _ref.read(ftpServerProvider);
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
    } finally {
      _isTicking = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _loadRepositories() async {
    await _ref.read(ftpServerProvider.notifier).loadServers();
    await _ref.read(syncRuleProvider.notifier).loadRules();
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
