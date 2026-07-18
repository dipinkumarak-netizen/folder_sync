import 'dart:io';

import 'package:ftpconnect/ftpconnect.dart';
import 'package:path/path.dart' as path;

import '../ftp/models/ftp_server_model.dart';

/// ===============================================================
/// OpenBackup
/// File : restore_repository.dart
/// Version : 1.0.0
/// Description : FTP restore preview and download runner.
/// ===============================================================

class RestoreFileEntry {
  final String relativePath;
  final int size;
  final DateTime? modifiedAt;

  const RestoreFileEntry({
    required this.relativePath,
    required this.size,
    required this.modifiedAt,
  });
}

class RestorePreviewResult {
  final bool success;
  final String message;
  final List<RestoreFileEntry> files;

  const RestorePreviewResult({
    required this.success,
    required this.message,
    required this.files,
  });

  int get totalBytes => files.fold<int>(0, (sum, file) => sum + file.size);
}

enum RestoreConflictRule { skipExisting, overwriteExisting, keepBoth }

class RestoreRunResult {
  final bool success;
  final String message;
  final int filesRestored;
  final int filesSkipped;
  final int filesOverwritten;
  final int filesKeptBoth;
  final int bytesRestored;

  const RestoreRunResult({
    required this.success,
    required this.message,
    required this.filesRestored,
    required this.filesSkipped,
    required this.filesOverwritten,
    required this.filesKeptBoth,
    required this.bytesRestored,
  });
}

enum _RestoreDownloadAction { restored, skipped, overwritten, keptBoth }

class RestoreRepository {
  RestoreRepository._();

  static final RestoreRepository instance = RestoreRepository._();

  Future<RestorePreviewResult> previewFiles({
    required FtpServerModel ftpServer,
    required String remoteFolderPath,
  }) async {
    final ftpConnect = _connectFor(ftpServer);
    var connected = false;

    try {
      connected = await ftpConnect.connect();
      if (!connected) {
        return const RestorePreviewResult(
          success: false,
          message: 'Could not connect to the FTP server.',
          files: [],
        );
      }

      final remoteRoot = _normalizeRemotePath(remoteFolderPath);
      final files = await _collectRemoteFiles(
        ftpConnect: ftpConnect,
        remoteRoot: remoteRoot,
      );

      return RestorePreviewResult(
        success: true,
        message: files.isEmpty
            ? 'No files found in this remote folder.'
            : 'Preview found ${files.length} file(s).',
        files: files,
      );
    } catch (_) {
      return const RestorePreviewResult(
        success: false,
        message:
            'Restore preview failed. Check the remote folder and FTP server.',
        files: [],
      );
    } finally {
      if (connected) {
        await ftpConnect.disconnect();
      }
    }
  }

  Future<RestoreRunResult> runRestore({
    required FtpServerModel ftpServer,
    required String remoteFolderPath,
    required String localFolderPath,
    required RestoreConflictRule conflictRule,
  }) async {
    final localDirectory = Directory(localFolderPath);
    if (!await localDirectory.exists()) {
      return const RestoreRunResult(
        success: false,
        message: 'Destination folder is not available.',
        filesRestored: 0,
        filesSkipped: 0,
        filesOverwritten: 0,
        filesKeptBoth: 0,
        bytesRestored: 0,
      );
    }

    final ftpConnect = _connectFor(ftpServer);
    var connected = false;

    try {
      connected = await ftpConnect.connect();
      if (!connected) {
        return const RestoreRunResult(
          success: false,
          message: 'Could not connect to the FTP server.',
          filesRestored: 0,
          filesSkipped: 0,
          filesOverwritten: 0,
          filesKeptBoth: 0,
          bytesRestored: 0,
        );
      }

      final remoteRoot = _normalizeRemotePath(remoteFolderPath);
      final files = await _collectRemoteFiles(
        ftpConnect: ftpConnect,
        remoteRoot: remoteRoot,
      );

      var filesRestored = 0;
      var filesSkipped = 0;
      var filesOverwritten = 0;
      var filesKeptBoth = 0;
      var bytesRestored = 0;

      for (final file in files) {
        final action = await _downloadFile(
          ftpConnect: ftpConnect,
          remoteRoot: remoteRoot,
          localDirectory: localDirectory,
          remoteFile: file,
          conflictRule: conflictRule,
        );
        switch (action) {
          case _RestoreDownloadAction.skipped:
            filesSkipped += 1;
          case _RestoreDownloadAction.overwritten:
            filesOverwritten += 1;
            filesRestored += 1;
            bytesRestored += file.size;
          case _RestoreDownloadAction.keptBoth:
            filesKeptBoth += 1;
            filesRestored += 1;
            bytesRestored += file.size;
          case _RestoreDownloadAction.restored:
            filesRestored += 1;
            bytesRestored += file.size;
        }
      }

      final skipNote = filesSkipped == 0 ? '' : ' Skipped $filesSkipped.';
      final overwriteNote = filesOverwritten == 0
          ? ''
          : ' Overwrote $filesOverwritten.';
      final keepBothNote = filesKeptBoth == 0
          ? ''
          : ' Kept both for $filesKeptBoth.';
      return RestoreRunResult(
        success: true,
        message: filesRestored == 0
            ? 'No files restored.$skipNote'
            : 'Restored $filesRestored file(s).$skipNote$overwriteNote$keepBothNote',
        filesRestored: filesRestored,
        filesSkipped: filesSkipped,
        filesOverwritten: filesOverwritten,
        filesKeptBoth: filesKeptBoth,
        bytesRestored: bytesRestored,
      );
    } catch (_) {
      return const RestoreRunResult(
        success: false,
        message: 'Restore failed. Check folders and FTP server.',
        filesRestored: 0,
        filesSkipped: 0,
        filesOverwritten: 0,
        filesKeptBoth: 0,
        bytesRestored: 0,
      );
    } finally {
      if (connected) {
        await ftpConnect.disconnect();
      }
    }
  }

  FTPConnect _connectFor(FtpServerModel ftpServer) {
    return FTPConnect(
      ftpServer.host,
      port: ftpServer.port,
      user: ftpServer.isAnonymous ? 'anonymous' : ftpServer.username,
      pass: ftpServer.isAnonymous ? '' : ftpServer.password,
      timeout: 30,
    );
  }

  Future<List<RestoreFileEntry>> _collectRemoteFiles({
    required FTPConnect ftpConnect,
    required String remoteRoot,
  }) async {
    final files = <RestoreFileEntry>[];
    await _changeRemoteDirectory(ftpConnect, remoteRoot);
    await _collectRemoteFilesInDirectory(
      ftpConnect: ftpConnect,
      remoteRoot: remoteRoot,
      relativeDirectory: '.',
      files: files,
    );
    files.sort(
      (first, second) => first.relativePath.compareTo(second.relativePath),
    );
    return files;
  }

  Future<void> _collectRemoteFilesInDirectory({
    required FTPConnect ftpConnect,
    required String remoteRoot,
    required String relativeDirectory,
    required List<RestoreFileEntry> files,
  }) async {
    await _changeRemoteDirectory(ftpConnect, remoteRoot);
    if (relativeDirectory != '.') {
      await _changeRemoteDirectory(ftpConnect, relativeDirectory);
    }

    final entries = await ftpConnect.listDirectoryContent();
    for (final entry in entries) {
      final relativePath = relativeDirectory == '.'
          ? entry.name
          : path.posix.join(relativeDirectory, entry.name);
      final safeRelativePath = _safeRelativePath(relativePath);
      if (entry.type == FTPEntryType.dir) {
        await _collectRemoteFilesInDirectory(
          ftpConnect: ftpConnect,
          remoteRoot: remoteRoot,
          relativeDirectory: safeRelativePath,
          files: files,
        );
        continue;
      }

      if (entry.type != FTPEntryType.file) {
        continue;
      }

      files.add(
        RestoreFileEntry(
          relativePath: safeRelativePath,
          size: entry.size ?? 0,
          modifiedAt: entry.modifyTime,
        ),
      );
    }
  }

  Future<_RestoreDownloadAction> _downloadFile({
    required FTPConnect ftpConnect,
    required String remoteRoot,
    required Directory localDirectory,
    required RestoreFileEntry remoteFile,
    required RestoreConflictRule conflictRule,
  }) async {
    final localRootPath = path.normalize(localDirectory.path);
    final localFilePath = path.normalize(
      path.join(localRootPath, remoteFile.relativePath),
    );
    if (!path.isWithin(localRootPath, localFilePath)) {
      throw StateError('Refusing to restore outside the destination folder.');
    }

    final downloadAction = await _downloadActionFor(
      localFilePath: localFilePath,
      conflictRule: conflictRule,
    );
    if (downloadAction == _RestoreDownloadAction.skipped) {
      return downloadAction;
    }

    final localFile = File(
      _targetPathForConflict(
        localFilePath: localFilePath,
        conflictRule: conflictRule,
      ),
    );
    if (downloadAction == _RestoreDownloadAction.overwritten &&
        await localFile.exists()) {
      await localFile.delete();
    }
    await localFile.parent.create(recursive: true);
    await _changeRemoteDirectory(ftpConnect, remoteRoot);
    final remoteDirectory = path.posix.dirname(remoteFile.relativePath);
    if (remoteDirectory != '.') {
      await _changeRemoteDirectory(ftpConnect, remoteDirectory);
    }

    final downloaded = await ftpConnect.downloadFile(
      path.posix.basename(remoteFile.relativePath),
      localFile,
    );
    if (!downloaded) {
      throw StateError('Could not restore ${remoteFile.relativePath}.');
    }

    return downloadAction;
  }

  Future<_RestoreDownloadAction> _downloadActionFor({
    required String localFilePath,
    required RestoreConflictRule conflictRule,
  }) async {
    if (!await File(localFilePath).exists()) {
      return _RestoreDownloadAction.restored;
    }

    return switch (conflictRule) {
      RestoreConflictRule.skipExisting => _RestoreDownloadAction.skipped,
      RestoreConflictRule.overwriteExisting =>
        _RestoreDownloadAction.overwritten,
      RestoreConflictRule.keepBoth => _RestoreDownloadAction.keptBoth,
    };
  }

  String _targetPathForConflict({
    required String localFilePath,
    required RestoreConflictRule conflictRule,
  }) {
    if (conflictRule != RestoreConflictRule.keepBoth ||
        !File(localFilePath).existsSync()) {
      return localFilePath;
    }

    final directory = path.dirname(localFilePath);
    final extension = path.extension(localFilePath);
    final basename = path.basenameWithoutExtension(localFilePath);

    var copyNumber = 1;
    while (true) {
      final candidate = path.join(
        directory,
        '$basename.restored-copy-$copyNumber$extension',
      );
      if (!File(candidate).existsSync()) {
        return candidate;
      }

      copyNumber += 1;
    }
  }

  String _safeRelativePath(String relativePath) {
    final normalized = path.posix.normalize(relativePath);
    if (normalized == '.' ||
        normalized == '..' ||
        normalized.startsWith('../') ||
        path.posix.isAbsolute(normalized)) {
      throw StateError('Unsafe remote file path.');
    }

    return normalized;
  }

  String _normalizeRemotePath(String remotePath) {
    final trimmed = remotePath.trim();
    if (trimmed.isEmpty) {
      return '/';
    }

    return path.posix.normalize(trimmed);
  }

  Future<void> _changeRemoteDirectory(
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
        throw StateError('Could not open remote folder $part.');
      }
    }
  }
}
