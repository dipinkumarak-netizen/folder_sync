import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/history_repository.dart';
import '../models/history_entry_model.dart';

/// ===============================================================
/// OpenBackup
/// File : history_provider.dart
/// Version : 1.0.0
/// Description : Riverpod provider for operation history.
/// ===============================================================

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository.instance;
});

class HistoryNotifier extends StateNotifier<List<HistoryEntryModel>> {
  HistoryNotifier(this._repository) : super(_repository.getAll().toList());

  final HistoryRepository _repository;

  void refresh() {
    state = _repository.getAll().toList();
  }

  Future<void> loadEntries() async {
    await _repository.load();
    refresh();
  }

  Future<void> addEntry(HistoryEntryModel entry) async {
    _repository.add(entry);
    refresh();
  }

  Future<void> clearEntries() async {
    _repository.clear();
    refresh();
  }
}

final historyProvider =
    StateNotifierProvider<HistoryNotifier, List<HistoryEntryModel>>((ref) {
      final repository = ref.watch(historyRepositoryProvider);
      return HistoryNotifier(repository);
    });

final historyLoadProvider = FutureProvider<void>((ref) async {
  await ref.read(historyProvider.notifier).loadEntries();
});
