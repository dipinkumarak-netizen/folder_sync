import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../history/models/history_entry_model.dart';

/// ===============================================================
/// OpenBackup
/// File : history_repository.dart
/// Version : 1.0.0
/// Description : Persistent repository for backup and sync history.
/// ===============================================================

class HistoryRepository {
  HistoryRepository._();

  static final HistoryRepository instance = HistoryRepository._();

  final List<HistoryEntryModel> _entries = [];
  bool _loaded = false;

  UnmodifiableListView<HistoryEntryModel> getAll() {
    return UnmodifiableListView(_entries);
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

      _entries
        ..clear()
        ..addAll(
          decoded
              .whereType<Map<String, dynamic>>()
              .map(HistoryEntryModel.fromJson)
              .where((entry) => entry.id.isNotEmpty),
        );
      _sortNewestFirst();
    } catch (_) {
      return;
    }
  }

  void add(HistoryEntryModel entry) {
    _entries.insert(0, entry);
    _sortNewestFirst();
    unawaited(_save());
  }

  void clear() {
    _entries.clear();
    unawaited(_save());
  }

  Future<void> flush() {
    return _save();
  }

  void _sortNewestFirst() {
    _entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<File> _storageFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final storageDirectory = Directory('${directory.path}/openbackup');
    if (!await storageDirectory.exists()) {
      await storageDirectory.create(recursive: true);
    }

    return File('${storageDirectory.path}/history.json');
  }

  Future<void> _save() async {
    try {
      final file = await _storageFile();
      final encoded = jsonEncode(
        _entries.map((entry) => entry.toJson()).toList(),
      );
      await file.writeAsString(encoded);
    } catch (_) {
      return;
    }
  }
}
