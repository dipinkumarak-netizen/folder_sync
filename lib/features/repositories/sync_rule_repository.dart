import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:ftpconnect/ftpconnect.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../ftp/models/ftp_server_model.dart';
import '../sync/models/sync_rule_model.dart';

/// ===============================================================
/// OpenBackup
/// File : sync_rule_repository.dart
/// Version : 1.0.0
/// Description : Persistent repository for synchronization rules.
/// ===============================================================

class SyncRunResult {
  final bool success;
  final String message;
  final int filesChanged;
  final int bytesChanged;

  const SyncRunResult({
    required this.success,
    required this.message,
    required this.filesChanged,
    required this.bytesChanged,
  });
}

class _SyncFileEntry {
  final String relativePath;
  final int size;
  final DateTime? modifiedAt;

  const _SyncFileEntry({
    required this.relativePath,
    required this.size,
    required this.modifiedAt,
  });
}

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

  Future<SyncRunResult> runSync({
    required SyncRuleModel rule,
    required FtpServerModel ftpServer,
  }) async {
    final localDirectory = Directory(rule.localFolderPath);
    if (!await localDirectory.exists()) {
      return const SyncRunResult(
        success: false,
        message: 'Local folder is not available.',
        filesChanged: 0,
        bytesChanged: 0,
      );
    }

    if (_isDestructiveDeleteRule(rule.deleteRule)) {
      return const SyncRunResult(
        success: false,
        message: 'Delete sync rules need a protected preview step first.',
        filesChanged: 0,
        bytesChanged: 0,
      );
    }

    final ftpConnect = FTPConnect(
      ftpServer.host,
      port: ftpServer.port,
      user: ftpServer.isAnonymous ? 'anonymous' : ftpServer.username,
      pass: ftpServer.isAnonymous ? '' : ftpServer.password,
      timeout: 30,
    );

    var connected = false;
    try {
      connected = await ftpConnect.connect();
      if (!connected) {
        return const SyncRunResult(
          success: false,
          message: 'Could not connect to the FTP server.',
          filesChanged: 0,
          bytesChanged: 0,
        );
      }

      final remoteRoot = _normalizeRemotePath(rule.remoteFolderPath);
      await _changeOrCreateRemoteDirectory(ftpConnect, remoteRoot);

      final localFiles = await _collectLocalFiles(localDirectory, rule);
      final remoteFiles = await _collectRemoteFiles(
        ftpConnect: ftpConnect,
        remoteRoot: remoteRoot,
        rule: rule,
      );

      var filesChanged = 0;
      var bytesChanged = 0;

      if (_shouldUpload(rule.direction)) {
        final result = await _uploadPendingFiles(
          ftpConnect: ftpConnect,
          localDirectory: localDirectory,
          remoteRoot: remoteRoot,
          localFiles: localFiles,
          remoteFiles: remoteFiles,
          rule: rule,
        );
        filesChanged += result.filesChanged;
        bytesChanged += result.bytesChanged;
      }

      if (_shouldDownload(rule.direction)) {
        final result = await _downloadPendingFiles(
          ftpConnect: ftpConnect,
          localDirectory: localDirectory,
          remoteRoot: remoteRoot,
          localFiles: localFiles,
          remoteFiles: remoteFiles,
          rule: rule,
        );
        filesChanged += result.filesChanged;
        bytesChanged += result.bytesChanged;
      }

      final mirrorNote = _isMirrorRule(rule.direction)
          ? ' Delete mirroring was skipped until preview support is added.'
          : '';
      final message = filesChanged == 0
          ? 'No sync changes found.$mirrorNote'
          : 'Synchronized $filesChanged file(s).$mirrorNote';

      return SyncRunResult(
        success: true,
        message: message,
        filesChanged: filesChanged,
        bytesChanged: bytesChanged,
      );
    } catch (_) {
      return const SyncRunResult(
        success: false,
        message: 'Synchronization failed. Check folders and FTP server.',
        filesChanged: 0,
        bytesChanged: 0,
      );
    } finally {
      if (connected) {
        await ftpConnect.disconnect();
      }
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

  Future<SyncRunResult> _uploadPendingFiles({
    required FTPConnect ftpConnect,
    required Directory localDirectory,
    required String remoteRoot,
    required Map<String, _SyncFileEntry> localFiles,
    required Map<String, _SyncFileEntry> remoteFiles,
    required SyncRuleModel rule,
  }) async {
    var filesChanged = 0;
    var bytesChanged = 0;

    for (final localEntry in localFiles.values) {
      final remoteEntry = remoteFiles[localEntry.relativePath];
      final shouldUpload = _shouldTransferLocalToRemote(
        localEntry,
        remoteEntry,
        rule.conflictRule,
      );
      if (!shouldUpload) {
        continue;
      }

      final localFile = File(
        path.join(localDirectory.path, localEntry.relativePath),
      );
      final uploadName = _uploadName(
        localEntry.relativePath,
        remoteEntry,
        rule,
      );
      await _changeOrCreateRemoteDirectory(ftpConnect, remoteRoot);
      final remoteDirectory = path.posix.dirname(uploadName);
      if (remoteDirectory != '.') {
        await _changeOrCreateRemoteDirectory(ftpConnect, remoteDirectory);
      }

      final uploaded = await ftpConnect.uploadFile(
        localFile,
        sRemoteName: path.posix.basename(uploadName),
      );
      if (!uploaded) {
        throw StateError('Could not upload ${localEntry.relativePath}.');
      }

      filesChanged += 1;
      bytesChanged += localEntry.size;
    }

    return SyncRunResult(
      success: true,
      message: '',
      filesChanged: filesChanged,
      bytesChanged: bytesChanged,
    );
  }

  Future<SyncRunResult> _downloadPendingFiles({
    required FTPConnect ftpConnect,
    required Directory localDirectory,
    required String remoteRoot,
    required Map<String, _SyncFileEntry> localFiles,
    required Map<String, _SyncFileEntry> remoteFiles,
    required SyncRuleModel rule,
  }) async {
    var filesChanged = 0;
    var bytesChanged = 0;

    for (final remoteEntry in remoteFiles.values) {
      final localEntry = localFiles[remoteEntry.relativePath];
      final shouldDownload = _shouldTransferRemoteToLocal(
        localEntry,
        remoteEntry,
        rule.conflictRule,
      );
      if (!shouldDownload) {
        continue;
      }

      final localPath = _downloadPath(
        localDirectory.path,
        remoteEntry.relativePath,
        localEntry,
        rule,
      );
      final localFile = File(localPath);
      await localFile.parent.create(recursive: true);
      await _changeOrCreateRemoteDirectory(ftpConnect, remoteRoot);
      final remoteDirectory = path.posix.dirname(remoteEntry.relativePath);
      if (remoteDirectory != '.') {
        await _changeOrCreateRemoteDirectory(ftpConnect, remoteDirectory);
      }

      final downloaded = await ftpConnect.downloadFile(
        path.posix.basename(remoteEntry.relativePath),
        localFile,
      );
      if (!downloaded) {
        throw StateError('Could not download ${remoteEntry.relativePath}.');
      }

      filesChanged += 1;
      bytesChanged += remoteEntry.size;
    }

    return SyncRunResult(
      success: true,
      message: '',
      filesChanged: filesChanged,
      bytesChanged: bytesChanged,
    );
  }

  Future<Map<String, _SyncFileEntry>> _collectLocalFiles(
    Directory localDirectory,
    SyncRuleModel rule,
  ) async {
    final files = <String, _SyncFileEntry>{};
    await for (final entity in localDirectory.list(
      recursive: rule.syncSubfolders,
    )) {
      if (entity is! File) {
        continue;
      }

      final relativePath = _relativePath(localDirectory.path, entity.path);
      final stat = await entity.stat();
      if (!_matchesRule(
        relativePath: relativePath,
        name: path.basename(relativePath),
        size: stat.size,
        rule: rule,
      )) {
        continue;
      }

      files[relativePath] = _SyncFileEntry(
        relativePath: relativePath,
        size: stat.size,
        modifiedAt: stat.modified,
      );
    }

    return files;
  }

  Future<Map<String, _SyncFileEntry>> _collectRemoteFiles({
    required FTPConnect ftpConnect,
    required String remoteRoot,
    required SyncRuleModel rule,
  }) async {
    final files = <String, _SyncFileEntry>{};
    await _changeOrCreateRemoteDirectory(ftpConnect, remoteRoot);
    await _collectRemoteFilesInDirectory(
      ftpConnect: ftpConnect,
      remoteRoot: remoteRoot,
      relativeDirectory: '.',
      rule: rule,
      files: files,
    );
    return files;
  }

  Future<void> _collectRemoteFilesInDirectory({
    required FTPConnect ftpConnect,
    required String remoteRoot,
    required String relativeDirectory,
    required SyncRuleModel rule,
    required Map<String, _SyncFileEntry> files,
  }) async {
    await _changeOrCreateRemoteDirectory(ftpConnect, remoteRoot);
    if (relativeDirectory != '.') {
      await _changeOrCreateRemoteDirectory(ftpConnect, relativeDirectory);
    }

    final entries = await ftpConnect.listDirectoryContent();
    for (final entry in entries) {
      final relativePath = relativeDirectory == '.'
          ? entry.name
          : path.posix.join(relativeDirectory, entry.name);
      if (entry.type == FTPEntryType.dir && rule.syncSubfolders) {
        await _collectRemoteFilesInDirectory(
          ftpConnect: ftpConnect,
          remoteRoot: remoteRoot,
          relativeDirectory: relativePath,
          rule: rule,
          files: files,
        );
        continue;
      }

      if (entry.type != FTPEntryType.file) {
        continue;
      }

      if (!_matchesRule(
        relativePath: relativePath,
        name: entry.name,
        size: entry.size ?? 0,
        rule: rule,
      )) {
        continue;
      }

      files[relativePath] = _SyncFileEntry(
        relativePath: relativePath,
        size: entry.size ?? 0,
        modifiedAt: entry.modifyTime,
      );
    }
  }

  bool _shouldTransferLocalToRemote(
    _SyncFileEntry localEntry,
    _SyncFileEntry? remoteEntry,
    SyncConflictRule conflictRule,
  ) {
    if (remoteEntry == null) {
      return true;
    }

    return switch (conflictRule) {
      SyncConflictRule.localWins => true,
      SyncConflictRule.remoteWins => false,
      SyncConflictRule.keepBoth => true,
      SyncConflictRule.skip => false,
      SyncConflictRule.newerWins => _isNewer(localEntry, remoteEntry),
    };
  }

  bool _shouldTransferRemoteToLocal(
    _SyncFileEntry? localEntry,
    _SyncFileEntry remoteEntry,
    SyncConflictRule conflictRule,
  ) {
    if (localEntry == null) {
      return true;
    }

    return switch (conflictRule) {
      SyncConflictRule.localWins => false,
      SyncConflictRule.remoteWins => true,
      SyncConflictRule.keepBoth => true,
      SyncConflictRule.skip => false,
      SyncConflictRule.newerWins => _isNewer(remoteEntry, localEntry),
    };
  }

  bool _isNewer(_SyncFileEntry source, _SyncFileEntry target) {
    final sourceTime = source.modifiedAt;
    final targetTime = target.modifiedAt;
    if (sourceTime == null || targetTime == null) {
      return source.size != target.size;
    }

    return sourceTime.isAfter(targetTime) && source.size != target.size;
  }

  String _uploadName(
    String relativePath,
    _SyncFileEntry? remoteEntry,
    SyncRuleModel rule,
  ) {
    if (remoteEntry == null || rule.conflictRule != SyncConflictRule.keepBoth) {
      return relativePath;
    }

    return _copyName(relativePath, 'local');
  }

  String _downloadPath(
    String localRoot,
    String relativePath,
    _SyncFileEntry? localEntry,
    SyncRuleModel rule,
  ) {
    final targetRelativePath =
        localEntry != null && rule.conflictRule == SyncConflictRule.keepBoth
        ? _copyName(relativePath, 'remote')
        : relativePath;
    return path.join(localRoot, targetRelativePath);
  }

  String _copyName(String relativePath, String sourceLabel) {
    final directory = path.posix.dirname(relativePath);
    final extension = path.extension(relativePath);
    final basename = path.basenameWithoutExtension(relativePath);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = '$basename.$sourceLabel.$timestamp$extension';
    if (directory == '.') {
      return filename;
    }

    return path.posix.join(directory, filename);
  }

  bool _matchesRule({
    required String relativePath,
    required String name,
    required int size,
    required SyncRuleModel rule,
  }) {
    if (!rule.includeHiddenFiles && name.startsWith('.')) {
      return false;
    }

    final maxFileSizeMb = rule.maxFileSizeMb;
    if (maxFileSizeMb != null && size > maxFileSizeMb * 1024 * 1024) {
      return false;
    }

    final includePatterns = _patterns(rule.includePatterns);
    final excludePatterns = _patterns(rule.excludePatterns);
    final included =
        includePatterns.isEmpty ||
        includePatterns.any((pattern) => _globMatch(pattern, relativePath));
    final excluded = excludePatterns.any(
      (pattern) => _globMatch(pattern, relativePath),
    );
    return included && !excluded;
  }

  List<String> _patterns(String value) {
    return value
        .split(',')
        .map((pattern) => pattern.trim())
        .where((pattern) => pattern.isNotEmpty && pattern != '*')
        .toList();
  }

  bool _globMatch(String pattern, String value) {
    final escaped = RegExp.escape(pattern).replaceAll(r'\*', '.*');
    return RegExp('^$escaped\$').hasMatch(value);
  }

  bool _shouldUpload(SyncDirection direction) {
    return direction == SyncDirection.uploadOnly ||
        direction == SyncDirection.twoWay ||
        direction == SyncDirection.mirrorLocalToRemote;
  }

  bool _shouldDownload(SyncDirection direction) {
    return direction == SyncDirection.downloadOnly ||
        direction == SyncDirection.twoWay ||
        direction == SyncDirection.mirrorRemoteToLocal;
  }

  bool _isMirrorRule(SyncDirection direction) {
    return direction == SyncDirection.mirrorLocalToRemote ||
        direction == SyncDirection.mirrorRemoteToLocal;
  }

  bool _isDestructiveDeleteRule(SyncDeleteRule deleteRule) {
    return deleteRule != SyncDeleteRule.keepDeletedFiles;
  }

  String _relativePath(String from, String filePath) {
    final relativePath = path.relative(filePath, from: from);
    return path.split(relativePath).join('/');
  }

  String _normalizeRemotePath(String remotePath) {
    final trimmed = remotePath.trim();
    if (trimmed.isEmpty) {
      return '/';
    }

    return path.posix.normalize(trimmed);
  }

  Future<void> _changeOrCreateRemoteDirectory(
    FTPConnect ftpConnect,
    String remotePath,
  ) async {
    final normalizedPath = _normalizeRemotePath(remotePath);
    if (normalizedPath == '/' || normalizedPath == '.') {
      await ftpConnect.changeDirectory('/');
      return;
    }

    if (normalizedPath.startsWith('/')) {
      await ftpConnect.changeDirectory('/');
    }

    final parts = normalizedPath
        .split('/')
        .where((part) => part.isNotEmpty && part != '.')
        .toList();

    for (final part in parts) {
      final changed = await ftpConnect.changeDirectory(part);
      if (!changed) {
        final created = await ftpConnect.makeDirectory(part);
        if (!created) {
          throw StateError('Could not create remote folder $part.');
        }

        final changedAfterCreate = await ftpConnect.changeDirectory(part);
        if (!changedAfterCreate) {
          throw StateError('Could not open remote folder $part.');
        }
      }
    }
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
