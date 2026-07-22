import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/openbackup_database.dart';
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
      final database = await OpenBackupDatabase.instance.database;
      final storedEntries = await _loadFromDatabase(database);
      if (storedEntries.isNotEmpty) {
        _entries
          ..clear()
          ..addAll(storedEntries);
        _sortNewestFirst();
        return;
      }

      final legacyEntries = await _loadFromJson();
      if (legacyEntries.isEmpty) {
        return;
      }

      _entries
        ..clear()
        ..addAll(legacyEntries);
      _sortNewestFirst();
      await _saveToDatabase(database);
    } catch (_) {
      final legacyEntries = await _loadFromJson();
      _entries
        ..clear()
        ..addAll(legacyEntries);
      _sortNewestFirst();
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
      final database = await OpenBackupDatabase.instance.database;
      await _saveToDatabase(database);
      return;
    } catch (_) {
      await _saveToJson();
    }
  }

  Future<List<HistoryEntryModel>> _loadFromDatabase(Database database) async {
    final rows = await database.query(
      OpenBackupDatabase.historyEntriesTable,
      orderBy: 'created_at DESC',
    );
    return rows
        .map(_entryFromRow)
        .where((entry) => entry.id.isNotEmpty)
        .toList();
  }

  Future<void> _saveToDatabase(Database database) async {
    await database.transaction((transaction) async {
      await transaction.delete(OpenBackupDatabase.historyEntriesTable);
      for (final entry in _entries) {
        await transaction.insert(
          OpenBackupDatabase.historyEntriesTable,
          _entryToRow(entry),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<HistoryEntryModel>> _loadFromJson() async {
    try {
      final file = await _storageFile().timeout(const Duration(seconds: 1));
      if (!await file.exists()) {
        return const [];
      }

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) {
        return const [];
      }

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(HistoryEntryModel.fromJson)
          .where((entry) => entry.id.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveToJson() async {
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

  Map<String, Object?> _entryToRow(HistoryEntryModel entry) {
    return {
      'id': entry.id,
      'operation_type': entry.operationType.name,
      'status': entry.status.name,
      'title': entry.title,
      'message': entry.message,
      'source_path': entry.sourcePath,
      'target_path': entry.targetPath,
      'related_id': entry.relatedId,
      'created_at': entry.createdAt.toIso8601String(),
      'files_changed': entry.filesChanged,
      'bytes_changed': entry.bytesChanged,
      'file_reports': jsonEncode(
        entry.fileReports.map((item) => item.toJson()).toList(),
      ),
    };
  }

  HistoryEntryModel _entryFromRow(Map<String, Object?> row) {
    return HistoryEntryModel(
      id: row['id'] as String? ?? '',
      operationType: HistoryOperationType.values.firstWhere(
        (type) => type.name == row['operation_type'],
        orElse: () => HistoryOperationType.backup,
      ),
      status: HistoryEntryStatus.values.firstWhere(
        (status) => status.name == row['status'],
        orElse: () => HistoryEntryStatus.failed,
      ),
      title: row['title'] as String? ?? '',
      message: row['message'] as String? ?? '',
      sourcePath: row['source_path'] as String? ?? '',
      targetPath: row['target_path'] as String? ?? '',
      relatedId: row['related_id'] as String? ?? '',
      createdAt:
          DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      filesChanged: row['files_changed'] as int? ?? 0,
      bytesChanged: row['bytes_changed'] as int? ?? 0,
      fileReports: _fileReportsFromJson(row['file_reports'] as String?),
    );
  }

  List<HistoryFileReportItem> _fileReportsFromJson(String? value) {
    if (value == null || value.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) {
        return const [];
      }

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(HistoryFileReportItem.fromJson)
          .where((item) => item.relativePath.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
