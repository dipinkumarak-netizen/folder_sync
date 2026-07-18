import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:ftpconnect/ftpconnect.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../backup/models/backup_job_model.dart';
import '../ftp/models/ftp_server_model.dart';

/// ===============================================================
/// OpenBackup
/// File : backup_memory_repository.dart
/// Version : 1.0.0
/// Description : In-memory repository and runner for backup jobs.
/// ===============================================================

class BackupRunResult {
  final bool success;
  final String message;
  final int filesBackedUp;
  final int bytesBackedUp;
  final List<String> backedUpRelativePaths;

  const BackupRunResult({
    required this.success,
    required this.message,
    required this.filesBackedUp,
    required this.bytesBackedUp,
    required this.backedUpRelativePaths,
  });
}

class BackupMemoryRepository {
  BackupMemoryRepository._();

  static final BackupMemoryRepository instance = BackupMemoryRepository._();

  final List<BackupJobModel> _jobs = [];
  bool _loaded = false;

  UnmodifiableListView<BackupJobModel> getAll() {
    return UnmodifiableListView(_jobs);
  }

  Future<void> load() async {
    if (_loaded) {
      return;
    }

    _loaded = true;

    try {
      final file = await _storageFile();
      if (!await file.exists()) {
        return;
      }

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) {
        return;
      }

      _jobs
        ..clear()
        ..addAll(
          decoded
              .whereType<Map<String, dynamic>>()
              .map(BackupJobModel.fromJson)
              .where((job) => job.id.isNotEmpty),
        );
    } catch (_) {
      return;
    }
  }

  void add(BackupJobModel job) {
    _jobs.add(job);
    unawaited(_save());
  }

  bool update(BackupJobModel job) {
    final index = _jobs.indexWhere((e) => e.id == job.id);
    if (index == -1) {
      return false;
    }

    _jobs[index] = job;
    unawaited(_save());
    return true;
  }

  bool remove(String id) {
    final exists = _jobs.any((e) => e.id == id);
    _jobs.removeWhere((e) => e.id == id);
    unawaited(_save());
    return exists;
  }

  BackupJobModel? findById(String id) {
    try {
      return _jobs.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<BackupRunResult> runBackup({
    required BackupJobModel job,
    required FtpServerModel ftpServer,
  }) async {
    final localDirectory = Directory(job.localFolderPath);
    if (!await localDirectory.exists()) {
      return BackupRunResult(
        success: false,
        message: 'Local folder is not available.',
        filesBackedUp: 0,
        bytesBackedUp: 0,
        backedUpRelativePaths: job.backedUpRelativePaths,
      );
    }

    final List<File> pendingFiles;
    try {
      pendingFiles = await _collectPendingFiles(localDirectory, job);
    } catch (_) {
      return BackupRunResult(
        success: false,
        message: 'Could not read the selected local folder.',
        filesBackedUp: 0,
        bytesBackedUp: 0,
        backedUpRelativePaths: job.backedUpRelativePaths,
      );
    }

    if (pendingFiles.isEmpty) {
      return BackupRunResult(
        success: true,
        message: 'No new files found.',
        filesBackedUp: 0,
        bytesBackedUp: 0,
        backedUpRelativePaths: job.backedUpRelativePaths,
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
    final backedUpPaths = {...job.backedUpRelativePaths};
    var filesBackedUp = 0;
    var bytesBackedUp = 0;

    try {
      connected = await ftpConnect.connect();
      if (!connected) {
        return BackupRunResult(
          success: false,
          message: 'Could not connect to the FTP server.',
          filesBackedUp: 0,
          bytesBackedUp: 0,
          backedUpRelativePaths: job.backedUpRelativePaths,
        );
      }

      final remoteRoot = _normalizeRemotePath(job.remoteFolderPath);
      await _changeOrCreateRemoteDirectory(ftpConnect, remoteRoot);

      for (final file in pendingFiles) {
        final relativePath = _relativeFilePath(localDirectory.path, file.path);
        final remoteDirectory = path.posix.dirname(relativePath);
        await _changeOrCreateRemoteDirectory(ftpConnect, remoteRoot);
        if (remoteDirectory != '.') {
          await _changeOrCreateRemoteDirectory(ftpConnect, remoteDirectory);
        }

        final uploaded = await ftpConnect.uploadFile(
          file,
          sRemoteName: path.posix.basename(relativePath),
        );
        if (!uploaded) {
          return BackupRunResult(
            success: false,
            message: 'Failed while uploading $relativePath.',
            filesBackedUp: filesBackedUp,
            bytesBackedUp: bytesBackedUp,
            backedUpRelativePaths: backedUpPaths.toList()..sort(),
          );
        }

        backedUpPaths.add(relativePath);
        filesBackedUp += 1;
        bytesBackedUp += await file.length();
      }

      return BackupRunResult(
        success: true,
        message: 'Backed up $filesBackedUp new file(s).',
        filesBackedUp: filesBackedUp,
        bytesBackedUp: bytesBackedUp,
        backedUpRelativePaths: backedUpPaths.toList()..sort(),
      );
    } catch (_) {
      return BackupRunResult(
        success: false,
        message: 'Backup failed. Check the folder and FTP server.',
        filesBackedUp: filesBackedUp,
        bytesBackedUp: bytesBackedUp,
        backedUpRelativePaths: backedUpPaths.toList()..sort(),
      );
    } finally {
      if (connected) {
        await ftpConnect.disconnect();
      }
    }
  }

  Future<List<File>> _collectPendingFiles(
    Directory localDirectory,
    BackupJobModel job,
  ) async {
    final completedPaths = job.backedUpRelativePaths.toSet();
    final files = <File>[];
    await for (final entity in localDirectory.list(recursive: true)) {
      if (entity is! File) {
        continue;
      }

      final relativePath = _relativeFilePath(localDirectory.path, entity.path);
      if (!completedPaths.contains(relativePath)) {
        files.add(entity);
      }
    }

    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  String _relativeFilePath(String from, String filePath) {
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

  Future<File> _storageFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final storageDirectory = Directory('${directory.path}/openbackup');
    if (!await storageDirectory.exists()) {
      await storageDirectory.create(recursive: true);
    }

    return File('${storageDirectory.path}/backup_jobs.json');
  }

  Future<void> _save() async {
    try {
      final file = await _storageFile().timeout(const Duration(seconds: 1));
      final encoded = jsonEncode(_jobs.map((job) => job.toJson()).toList());
      await file.writeAsString(encoded);
    } catch (_) {
      return;
    }
  }
}
