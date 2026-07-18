import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../sync/models/sync_rule_model.dart';

/// ===============================================================
/// OpenBackup
/// File : sync_rule_repository.dart
/// Version : 1.0.0
/// Description : Persistent repository for synchronization rules.
/// ===============================================================

class SyncRuleRepository {
  SyncRuleRepository._();

  static final SyncRuleRepository instance = SyncRuleRepository._();

  final List<SyncRuleModel> _rules = [];
  bool _loaded = false;

  UnmodifiableListView<SyncRuleModel> getAll() {
    return UnmodifiableListView(_rules);
  }

  Future<void> load() async {
    if (_loaded) {
      return;
    }

    _loaded = true;

    try {
      final file = await _storageFile().timeout(const Duration(seconds: 1));
      if (!await file.exists()) {
        return;
      }

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) {
        return;
      }

      _rules
        ..clear()
        ..addAll(
          decoded
              .whereType<Map<String, dynamic>>()
              .map(SyncRuleModel.fromJson)
              .where((rule) => rule.id.isNotEmpty),
        );
    } catch (_) {
      return;
    }
  }

  void add(SyncRuleModel rule) {
    _rules.add(rule);
    unawaited(_save());
  }

  bool update(SyncRuleModel rule) {
    final index = _rules.indexWhere((item) => item.id == rule.id);
    if (index == -1) {
      return false;
    }

    _rules[index] = rule;
    unawaited(_save());
    return true;
  }

  bool remove(String id) {
    final exists = _rules.any((rule) => rule.id == id);
    _rules.removeWhere((rule) => rule.id == id);
    unawaited(_save());
    return exists;
  }

  SyncRuleModel? findById(String id) {
    try {
      return _rules.firstWhere((rule) => rule.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<File> _storageFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final storageDirectory = Directory('${directory.path}/openbackup');
    if (!await storageDirectory.exists()) {
      await storageDirectory.create(recursive: true);
    }

    return File('${storageDirectory.path}/sync_rules.json');
  }

  Future<void> _save() async {
    try {
      final file = await _storageFile();
      final encoded = jsonEncode(_rules.map((rule) => rule.toJson()).toList());
      await file.writeAsString(encoded);
    } catch (_) {
      return;
    }
  }
}
