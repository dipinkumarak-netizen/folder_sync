import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:ftpconnect/ftpconnect.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../core/utils/failure_message.dart';
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
  final List<String> runBackedUpRelativePaths;

  const BackupRunResult({
    required this.success,
    required this.message,
    required this.filesBackedUp,
    required this.bytesBackedUp,
    required this.backedUpRelativePaths,
    this.runBackedUpRelativePaths = const [],
  });
}

class BackupProgressUpdate {
  final int currentFileIndex;
  final int totalFiles;
  final String currentFilePath;
  final int filesBackedUp;
  final int bytesBackedUp;

  const BackupProgressUpdate({
    required this.currentFileIndex,
    required this.totalFiles,
    required this.currentFilePath,
    required this.filesBackedUp,
    required this.bytesBackedUp,
  });
}

typedef BackupProgressCallback =
    FutureOr<void> Function(BackupProgressUpdate update);

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
      final file = await _storageFile().timeout(const Duration(seconds: 1));
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

  Future<void> flush() {
    return _save();
  }

  Future<BackupRunResult> runBackup({
    required BackupJobModel job,
    required FtpServerModel ftpServer,
    BackupProgressCallback? onProgress,
  }) async {
    if (ftpServer.protocol == ServerProtocol.sftp) {
      return _runSftpBackup(job: job, ftpServer: ftpServer, onProgress: onProgress);
    }

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
    } catch (error) {
      return BackupRunResult(
        success: false,
        message: FailureMessage.from(
          error,
          operation: 'Backup',
          fallback: 'Could not read the selected local folder.',
        ),
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
    final runBackedUpPaths = <String>[];
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

      for (var index = 0; index < pendingFiles.length; index += 1) {
        final file = pendingFiles[index];
        final relativePath = _relativeFilePath(localDirectory.path, file.path);
        final fileLength = await file.length();
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
            runBackedUpRelativePaths: runBackedUpPaths..sort(),
          );
        }

        backedUpPaths.add(relativePath);
        runBackedUpPaths.add(relativePath);
        filesBackedUp += 1;
        bytesBackedUp += fileLength;
        await onProgress?.call(
          BackupProgressUpdate(
            currentFileIndex: index + 1,
            totalFiles: pendingFiles.length,
            currentFilePath: relativePath,
            filesBackedUp: filesBackedUp,
            bytesBackedUp: bytesBackedUp,
          ),
        );
      }

      return BackupRunResult(
        success: true,
        message: 'Backed up $filesBackedUp new file(s).',
        filesBackedUp: filesBackedUp,
        bytesBackedUp: bytesBackedUp,
        backedUpRelativePaths: backedUpPaths.toList()..sort(),
        runBackedUpRelativePaths: runBackedUpPaths..sort(),
      );
    } catch (error) {
      return BackupRunResult(
        success: false,
        message: FailureMessage.from(
          error,
          operation: 'Backup',
          fallback: 'Backup failed. Check the folder and FTP server.',
        ),
        filesBackedUp: filesBackedUp,
        bytesBackedUp: bytesBackedUp,
        backedUpRelativePaths: backedUpPaths.toList()..sort(),
        runBackedUpRelativePaths: runBackedUpPaths..sort(),
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
      try {
        await ftpConnect.changeDirectory('/');
      } catch (_) {}
      return;
    }

    if (normalizedPath.startsWith('/')) {
      try {
        await ftpConnect.changeDirectory('/');
      } catch (_) {}
    }

    final parts = normalizedPath
        .split('/')
        .where((part) => part.isNotEmpty && part != '.')
        .toList();

    for (final part in parts) {
      if (part.isEmpty) continue;
      final changed = await ftpConnect.changeDirectory(part);
      if (!changed) {
        final created = await ftpConnect.makeDirectory(part);
        if (!created) {
          throw StateError('Could not create remote folder "$part".');
        }

        final changedAfterCreate = await ftpConnect.changeDirectory(part);
        if (!changedAfterCreate) {
          throw StateError('Could not open remote folder "$part".');
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
      final file = await _storageFile();
      final encoded = jsonEncode(_jobs.map((job) => job.toJson()).toList());
      await file.writeAsString(encoded);
    } catch (_) {
      return;
    }
  }

  // ==========================================================
  // SFTP Backup
  // ==========================================================

  Future<BackupRunResult> _runSftpBackup({
    required BackupJobModel job,
    required FtpServerModel ftpServer,
    BackupProgressCallback? onProgress,
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
    } catch (error) {
      return BackupRunResult(
        success: false,
        message: FailureMessage.from(
          error,
          operation: 'SFTP Backup',
          fallback: 'Could not read local folder.',
        ),
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

    SSHClient? client;
    final backedUpPaths = {...job.backedUpRelativePaths};
    final runBackedUpPaths = <String>[];
    var filesBackedUp = 0;
    var bytesBackedUp = 0;

    try {
      client = SSHClient(
        await SSHSocket.connect(ftpServer.host, ftpServer.port,
            timeout: const Duration(seconds: 20)),
        username: ftpServer.username,
        onPasswordRequest: () => ftpServer.password,
      );

      final sftp = await client.sftp();
      final remoteRoot = _normalizeRemotePath(job.remoteFolderPath);

      for (var index = 0; index < pendingFiles.length; index += 1) {
        final file = pendingFiles[index];
        final relativePath = _relativeFilePath(localDirectory.path, file.path);
        final fileLength = await file.length();
        final remoteFilePath = path.posix.join(remoteRoot, relativePath);
        final remoteDirectory = path.posix.dirname(remoteFilePath);

        // Ensure remote directory exists
        await _ensureSftpDirectory(sftp, remoteDirectory);

        final remoteFile = await sftp.open(
          remoteFilePath,
          mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate,
        );
        await remoteFile.write(file.openRead().cast());

        backedUpPaths.add(relativePath);
        runBackedUpPaths.add(relativePath);
        filesBackedUp += 1;
        bytesBackedUp += fileLength;

        await onProgress?.call(
          BackupProgressUpdate(
            currentFileIndex: index + 1,
            totalFiles: pendingFiles.length,
            currentFilePath: relativePath,
            filesBackedUp: filesBackedUp,
            bytesBackedUp: bytesBackedUp,
          ),
        );
      }

      client.close();
      return BackupRunResult(
        success: true,
        message: 'Backed up $filesBackedUp new file(s) via SFTP.',
        filesBackedUp: filesBackedUp,
        bytesBackedUp: bytesBackedUp,
        backedUpRelativePaths: backedUpPaths.toList()..sort(),
        runBackedUpRelativePaths: runBackedUpPaths..sort(),
      );
    } catch (error) {
      client?.close();
      return BackupRunResult(
        success: false,
        message: FailureMessage.from(
          error,
          operation: 'SFTP Backup',
          fallback: 'SFTP backup failed.',
        ),
        filesBackedUp: filesBackedUp,
        bytesBackedUp: bytesBackedUp,
        backedUpRelativePaths: backedUpPaths.toList()..sort(),
        runBackedUpRelativePaths: runBackedUpPaths..sort(),
      );
    }
  }

  Future<void> _ensureSftpDirectory(SftpClient sftp, String remotePath) async {
    final normalizedPath = _normalizeRemotePath(remotePath);
    if (normalizedPath == '/' || normalizedPath == '.') return;

    final parts = normalizedPath.split('/').where((p) => p.isNotEmpty).toList();
    var current = '';
    for (final part in parts) {
      current = '$current/$part';
      try {
        await sftp.stat(current);
      } catch (_) {
        await sftp.mkdir(current);
      }
    }
  }
}
