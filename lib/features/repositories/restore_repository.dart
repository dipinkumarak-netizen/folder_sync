import 'dart:async';
import 'dart:io';

import 'package:ftpconnect/ftpconnect.dart';
import 'package:path/path.dart' as path;

import '../../core/utils/failure_message.dart';
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

class RestoreFilterOptions {
  final bool includeSubfolders;
  final bool includeHiddenFiles;
  final String includePatterns;
  final String excludePatterns;
  final int? maxFileSizeMb;

  const RestoreFilterOptions({
    this.includeSubfolders = true,
    this.includeHiddenFiles = false,
    this.includePatterns = '*',
    this.excludePatterns = '',
    this.maxFileSizeMb,
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

class RestoreConflictPreviewResult {
  final int filesToRestore;
  final int filesSkipped;
  final int filesOverwritten;
  final int filesKeptBoth;
  final int bytesToRestore;
  final List<RestoreFileEntry> conflictingFiles;

  const RestoreConflictPreviewResult({
    required this.filesToRestore,
    required this.filesSkipped,
    required this.filesOverwritten,
    required this.filesKeptBoth,
    required this.bytesToRestore,
    required this.conflictingFiles,
  });

  const RestoreConflictPreviewResult.empty()
    : filesToRestore = 0,
      filesSkipped = 0,
      filesOverwritten = 0,
      filesKeptBoth = 0,
      bytesToRestore = 0,
      conflictingFiles = const [];

  int get existingConflicts => conflictingFiles.length;
}

class RestoreRunResult {
  final bool success;
  final bool cancelled;
  final String message;
  final int filesRestored;
  final int filesSkipped;
  final int filesOverwritten;
  final int filesKeptBoth;
  final int bytesRestored;
  final List<String> restoredRelativePaths;
  final List<String> skippedRelativePaths;
  final List<String> overwrittenRelativePaths;
  final List<String> keptBothRelativePaths;

  const RestoreRunResult({
    required this.success,
    this.cancelled = false,
    required this.message,
    required this.filesRestored,
    required this.filesSkipped,
    required this.filesOverwritten,
    required this.filesKeptBoth,
    required this.bytesRestored,
    this.restoredRelativePaths = const [],
    this.skippedRelativePaths = const [],
    this.overwrittenRelativePaths = const [],
    this.keptBothRelativePaths = const [],
  });
}

enum _RestoreDownloadAction { restored, skipped, overwritten, keptBoth }

class RestoreProgressUpdate {
  final int currentFileIndex;
  final int totalFiles;
  final String currentFilePath;
  final int filesRestored;
  final int filesSkipped;
  final int filesOverwritten;
  final int filesKeptBoth;
  final int bytesRestored;

  const RestoreProgressUpdate({
    required this.currentFileIndex,
    required this.totalFiles,
    required this.currentFilePath,
    required this.filesRestored,
    required this.filesSkipped,
    required this.filesOverwritten,
    required this.filesKeptBoth,
    required this.bytesRestored,
  });

  double get progress {
    if (totalFiles == 0) {
      return 0;
    }

    return currentFileIndex / totalFiles;
  }
}

typedef RestoreProgressCallback =
    FutureOr<void> Function(RestoreProgressUpdate update);

class RestoreCancellationToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}

class RestoreRepository {
  RestoreRepository._();

  static final RestoreRepository instance = RestoreRepository._();

  Future<RestorePreviewResult> previewFiles({
    required FtpServerModel ftpServer,
    required String remoteFolderPath,
    required RestoreFilterOptions filterOptions,
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
        filterOptions: filterOptions,
      );

      return RestorePreviewResult(
        success: true,
        message: files.isEmpty
            ? 'No files found in this remote folder.'
            : 'Preview found ${files.length} file(s).',
        files: files,
      );
    } catch (error) {
      return RestorePreviewResult(
        success: false,
        message: FailureMessage.from(
          error,
          operation: 'Restore preview',
          fallback:
              'Restore preview failed. Check the remote folder and FTP server.',
        ),
        files: const [],
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
    required RestoreFilterOptions filterOptions,
    RestoreProgressCallback? onProgress,
    RestoreCancellationToken? cancellationToken,
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
        filterOptions: filterOptions,
      );

      var filesRestored = 0;
      var filesSkipped = 0;
      var filesOverwritten = 0;
      var filesKeptBoth = 0;
      var bytesRestored = 0;
      final restoredPaths = <String>[];
      final skippedPaths = <String>[];
      final overwrittenPaths = <String>[];
      final keptBothPaths = <String>[];

      for (var index = 0; index < files.length; index += 1) {
        if (cancellationToken?.isCancelled == true) {
          return RestoreRunResult(
            success: false,
            cancelled: true,
            message: _cancelledMessage(
              filesRestored: filesRestored,
              filesSkipped: filesSkipped,
            ),
            filesRestored: filesRestored,
            filesSkipped: filesSkipped,
            filesOverwritten: filesOverwritten,
            filesKeptBoth: filesKeptBoth,
            bytesRestored: bytesRestored,
            restoredRelativePaths: restoredPaths,
            skippedRelativePaths: skippedPaths,
            overwrittenRelativePaths: overwrittenPaths,
            keptBothRelativePaths: keptBothPaths,
          );
        }

        final file = files[index];
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
            skippedPaths.add(file.relativePath);
          case _RestoreDownloadAction.overwritten:
            filesOverwritten += 1;
            filesRestored += 1;
            bytesRestored += file.size;
            overwrittenPaths.add(file.relativePath);
          case _RestoreDownloadAction.keptBoth:
            filesKeptBoth += 1;
            filesRestored += 1;
            bytesRestored += file.size;
            keptBothPaths.add(file.relativePath);
          case _RestoreDownloadAction.restored:
            filesRestored += 1;
            bytesRestored += file.size;
            restoredPaths.add(file.relativePath);
        }

        await onProgress?.call(
          RestoreProgressUpdate(
            currentFileIndex: index + 1,
            totalFiles: files.length,
            currentFilePath: file.relativePath,
            filesRestored: filesRestored,
            filesSkipped: filesSkipped,
            filesOverwritten: filesOverwritten,
            filesKeptBoth: filesKeptBoth,
            bytesRestored: bytesRestored,
          ),
        );
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
        restoredRelativePaths: restoredPaths,
        skippedRelativePaths: skippedPaths,
        overwrittenRelativePaths: overwrittenPaths,
        keptBothRelativePaths: keptBothPaths,
      );
    } catch (error) {
      return RestoreRunResult(
        success: false,
        message: FailureMessage.from(
          error,
          operation: 'Restore',
          fallback: 'Restore failed. Check folders and FTP server.',
        ),
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

  String _cancelledMessage({
    required int filesRestored,
    required int filesSkipped,
  }) {
    final skipNote = filesSkipped == 0 ? '' : ' Skipped $filesSkipped.';
    return 'Restore cancelled after $filesRestored restored file(s).$skipNote';
  }

  Future<RestoreConflictPreviewResult> previewLocalConflicts({
    required List<RestoreFileEntry> files,
    required String localFolderPath,
    required RestoreConflictRule conflictRule,
  }) async {
    final localDirectory = Directory(localFolderPath);
    if (!await localDirectory.exists()) {
      return const RestoreConflictPreviewResult.empty();
    }

    final localRootPath = path.normalize(localDirectory.path);
    final conflictingFiles = <RestoreFileEntry>[];
    var filesToRestore = 0;
    var bytesToRestore = 0;

    for (final file in files) {
      final localFilePath = path.normalize(
        path.join(localRootPath, file.relativePath),
      );
      if (!path.isWithin(localRootPath, localFilePath)) {
        throw StateError('Refusing to preview outside the destination folder.');
      }

      final exists = await File(localFilePath).exists();
      if (exists) {
        conflictingFiles.add(file);
        if (conflictRule == RestoreConflictRule.skipExisting) {
          continue;
        }
      }

      filesToRestore += 1;
      bytesToRestore += file.size;
    }

    final existingCount = conflictingFiles.length;
    return RestoreConflictPreviewResult(
      filesToRestore: filesToRestore,
      filesSkipped: conflictRule == RestoreConflictRule.skipExisting
          ? existingCount
          : 0,
      filesOverwritten: conflictRule == RestoreConflictRule.overwriteExisting
          ? existingCount
          : 0,
      filesKeptBoth: conflictRule == RestoreConflictRule.keepBoth
          ? existingCount
          : 0,
      bytesToRestore: bytesToRestore,
      conflictingFiles: conflictingFiles,
    );
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
    required RestoreFilterOptions filterOptions,
  }) async {
    final files = <RestoreFileEntry>[];
    await _changeRemoteDirectory(ftpConnect, remoteRoot);
    await _collectRemoteFilesInDirectory(
      ftpConnect: ftpConnect,
      remoteRoot: remoteRoot,
      relativeDirectory: '.',
      filterOptions: filterOptions,
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
    required RestoreFilterOptions filterOptions,
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
      if (entry.type == FTPEntryType.dir && filterOptions.includeSubfolders) {
        await _collectRemoteFilesInDirectory(
          ftpConnect: ftpConnect,
          remoteRoot: remoteRoot,
          relativeDirectory: safeRelativePath,
          filterOptions: filterOptions,
          files: files,
        );
        continue;
      }

      if (entry.type != FTPEntryType.file) {
        continue;
      }

      if (!_matchesFilter(
        relativePath: safeRelativePath,
        name: entry.name,
        size: entry.size ?? 0,
        filterOptions: filterOptions,
      )) {
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

  bool _matchesFilter({
    required String relativePath,
    required String name,
    required int size,
    required RestoreFilterOptions filterOptions,
  }) {
    if (!filterOptions.includeHiddenFiles && name.startsWith('.')) {
      return false;
    }

    final maxFileSizeMb = filterOptions.maxFileSizeMb;
    if (maxFileSizeMb != null && size > maxFileSizeMb * 1024 * 1024) {
      return false;
    }

    final includePatterns = _patterns(filterOptions.includePatterns);
    final excludePatterns = _patterns(filterOptions.excludePatterns);
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
        throw StateError('Could not open remote folder "$part".');
      }
    }
  }
}
