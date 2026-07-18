import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/sync_rule_repository.dart';
import '../models/sync_rule_model.dart';

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
  SyncRuleNotifier(this._repository) : super(_repository.getAll().toList());

  final SyncRuleRepository _repository;

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
}

final syncRuleProvider =
    StateNotifierProvider<SyncRuleNotifier, List<SyncRuleModel>>((ref) {
      final repository = ref.watch(syncRuleRepositoryProvider);
      return SyncRuleNotifier(repository);
    });

final syncRuleLoadProvider = FutureProvider<void>((ref) async {
  await ref.read(syncRuleProvider.notifier).loadRules();
});
