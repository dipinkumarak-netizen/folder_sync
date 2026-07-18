import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../ftp/models/ftp_server_model.dart';
import '../../history/models/history_entry_model.dart';
import '../../history/providers/history_provider.dart';
import '../../repositories/sync_rule_repository.dart';
import '../models/sync_rule_model.dart';
import '../services/wifi_status_service.dart';

/// ===============================================================
/// OpenBackup
/// File : sync_rule_provider.dart
/// Version : 1.0.0
/// Description : Riverpod provider for synchronization rules.
/// ===============================================================

final syncRuleRepositoryProvider = Provider<SyncRuleRepository>((ref) {
  return SyncRuleRepository.instance;
});

class SyncRuleNotifier extends StateNotifier<List<SyncRuleModel>> {
  SyncRuleNotifier(this._repository, this._historyNotifier)
    : super(_repository.getAll().toList());

  final SyncRuleRepository _repository;
  final HistoryNotifier _historyNotifier;

  void refresh() {
    state = _repository.getAll().toList();
  }

  Future<void> loadRules() async {
    await _repository.load();
    refresh();
  }

  Future<void> addRule(SyncRuleModel rule) async {
    _repository.add(rule);
    refresh();
  }

  Future<void> updateRule(SyncRuleModel rule) async {
    _repository.update(rule);
    refresh();
  }

  Future<void> deleteRule(String id) async {
    _repository.remove(id);
    refresh();
  }

  Future<void> toggleRule(String id, bool enabled) async {
    final rule = _repository.findById(id);
    if (rule == null) {
      return;
    }

    _repository.update(rule.copyWith(enabled: enabled));
    refresh();
  }

  Future<SyncRunResult> runRule({
    required SyncRuleModel rule,
    required FtpServerModel ftpServer,
  }) async {
    if (!rule.enabled) {
      return const SyncRunResult(
        success: false,
        message: 'Enable this sync rule before running it.',
        filesChanged: 0,
        bytesChanged: 0,
      );
    }

    final networkCheck = await _checkNetworkPolicy(rule);
    if (!networkCheck.success) {
      final failedRule = _completeRule(rule, networkCheck);
      _repository.update(failedRule);
      await _writeHistory(failedRule, ftpServer, networkCheck);
      refresh();
      return networkCheck;
    }

    final runningRule = rule.copyWith(
      status: SyncRuleStatus.running,
      lastMessage: 'Synchronization is running...',
    );
    _repository.update(runningRule);
    refresh();

    SyncRunResult result;
    try {
      result = await _repository.runSync(
        rule: runningRule,
        ftpServer: ftpServer,
      );
    } catch (_) {
      result = const SyncRunResult(
        success: false,
        message: 'Synchronization failed unexpectedly.',
        filesChanged: 0,
        bytesChanged: 0,
      );
    }

    final completedRule = _completeRule(runningRule, result);
    _repository.update(completedRule);
    await _writeHistory(completedRule, ftpServer, result);
    refresh();

    return result;
  }

  SyncRuleModel _completeRule(SyncRuleModel rule, SyncRunResult result) {
    return rule.copyWith(
      status: result.success ? SyncRuleStatus.success : SyncRuleStatus.failed,
      lastRunAt: DateTime.now(),
      lastMessage: result.message,
      lastFilesChanged: result.filesChanged,
      totalFilesChanged: rule.totalFilesChanged + result.filesChanged,
      totalBytesChanged: rule.totalBytesChanged + result.bytesChanged,
    );
  }

  Future<SyncRunResult> _checkNetworkPolicy(SyncRuleModel rule) async {
    if (!rule.runOnWifiOnly && rule.homeWifiName.trim().isEmpty) {
      return const SyncRunResult(
        success: true,
        message: '',
        filesChanged: 0,
        bytesChanged: 0,
      );
    }

    final connectivity = await Connectivity().checkConnectivity();
    final isWifi = connectivity.contains(ConnectivityResult.wifi);
    if (!isWifi) {
      return const SyncRunResult(
        success: false,
        message: 'Sync skipped because Wi-Fi is not connected.',
        filesChanged: 0,
        bytesChanged: 0,
      );
    }

    final expectedSsid = rule.homeWifiName.trim();
    if (expectedSsid.isEmpty) {
      return const SyncRunResult(
        success: true,
        message: '',
        filesChanged: 0,
        bytesChanged: 0,
      );
    }

    final hasWifiPermission = await _requestWifiNamePermissions();
    if (!hasWifiPermission) {
      return const SyncRunResult(
        success: false,
        message: 'Sync skipped because Wi-Fi name permission was not granted.',
        filesChanged: 0,
        bytesChanged: 0,
      );
    }

    final currentSsid = await WifiStatusService.currentSsid();
    if (currentSsid == null) {
      return const SyncRunResult(
        success: false,
        message: 'Sync skipped because the current Wi-Fi name is unavailable.',
        filesChanged: 0,
        bytesChanged: 0,
      );
    }

    if (currentSsid != expectedSsid) {
      return SyncRunResult(
        success: false,
        message: 'Sync skipped because Wi-Fi is "$currentSsid".',
        filesChanged: 0,
        bytesChanged: 0,
      );
    }

    return const SyncRunResult(
      success: true,
      message: '',
      filesChanged: 0,
      bytesChanged: 0,
    );
  }

  Future<bool> _requestWifiNamePermissions() async {
    final nearbyStatus = await Permission.nearbyWifiDevices.request();
    final locationStatus = await Permission.locationWhenInUse.request();
    return nearbyStatus.isGranted || locationStatus.isGranted;
  }

  Future<void> _writeHistory(
    SyncRuleModel rule,
    FtpServerModel ftpServer,
    SyncRunResult result,
  ) async {
    await _historyNotifier.addEntry(
      HistoryEntryModel(
        id: '${rule.id}-${DateTime.now().microsecondsSinceEpoch}',
        operationType: HistoryOperationType.sync,
        status: result.success
            ? HistoryEntryStatus.success
            : HistoryEntryStatus.failed,
        title: rule.name,
        message: result.message,
        sourcePath: rule.localFolderPath,
        targetPath: '${ftpServer.name}:${rule.remoteFolderPath}',
        relatedId: rule.id,
        createdAt: DateTime.now(),
        filesChanged: result.filesChanged,
        bytesChanged: result.bytesChanged,
      ),
    );
  }
}

final syncRuleProvider =
    StateNotifierProvider<SyncRuleNotifier, List<SyncRuleModel>>((ref) {
      final repository = ref.watch(syncRuleRepositoryProvider);
      final historyNotifier = ref.watch(historyProvider.notifier);
      return SyncRuleNotifier(repository, historyNotifier);
    });

final syncRuleLoadProvider = FutureProvider<void>((ref) async {
  await ref.read(syncRuleProvider.notifier).loadRules();
});
