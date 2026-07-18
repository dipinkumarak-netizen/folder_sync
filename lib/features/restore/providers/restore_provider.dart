import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ftp/models/ftp_server_model.dart';
import '../../history/models/history_entry_model.dart';
import '../../history/providers/history_provider.dart';
import '../../repositories/restore_repository.dart';
import '../../settings/models/app_settings_model.dart';
import '../../settings/providers/app_settings_provider.dart';
import '../services/restore_foreground_service.dart';

/// ===============================================================
/// OpenBackup
/// File : restore_provider.dart
/// Version : 1.0.0
/// Description : Riverpod provider for FTP restore operations.
/// ===============================================================

enum RestoreStatus {
  idle,
  previewing,
  ready,
  running,
  cancelling,
  success,
  failed,
  cancelled,
}

class RestoreState {
  final RestoreStatus status;
  final String message;
  final List<RestoreFileEntry> previewFiles;
  final RestoreConflictPreviewResult conflictPreview;
  final int currentFileIndex;
  final int totalFiles;
  final String currentFilePath;
  final bool cancelRequested;
  final int lastFilesRestored;
  final int lastFilesSkipped;
  final int lastFilesOverwritten;
  final int lastFilesKeptBoth;
  final int lastBytesRestored;

  const RestoreState({
    this.status = RestoreStatus.idle,
    this.message = 'Select a backup folder to restore.',
    this.previewFiles = const [],
    this.conflictPreview = const RestoreConflictPreviewResult.empty(),
    this.currentFileIndex = 0,
    this.totalFiles = 0,
    this.currentFilePath = '',
    this.cancelRequested = false,
    this.lastFilesRestored = 0,
    this.lastFilesSkipped = 0,
    this.lastFilesOverwritten = 0,
    this.lastFilesKeptBoth = 0,
    this.lastBytesRestored = 0,
  });

  RestoreState copyWith({
    RestoreStatus? status,
    String? message,
    List<RestoreFileEntry>? previewFiles,
    RestoreConflictPreviewResult? conflictPreview,
    int? currentFileIndex,
    int? totalFiles,
    String? currentFilePath,
    bool? cancelRequested,
    int? lastFilesRestored,
    int? lastFilesSkipped,
    int? lastFilesOverwritten,
    int? lastFilesKeptBoth,
    int? lastBytesRestored,
  }) {
    return RestoreState(
      status: status ?? this.status,
      message: message ?? this.message,
      previewFiles: previewFiles ?? this.previewFiles,
      conflictPreview: conflictPreview ?? this.conflictPreview,
      currentFileIndex: currentFileIndex ?? this.currentFileIndex,
      totalFiles: totalFiles ?? this.totalFiles,
      currentFilePath: currentFilePath ?? this.currentFilePath,
      cancelRequested: cancelRequested ?? this.cancelRequested,
      lastFilesRestored: lastFilesRestored ?? this.lastFilesRestored,
      lastFilesSkipped: lastFilesSkipped ?? this.lastFilesSkipped,
      lastFilesOverwritten: lastFilesOverwritten ?? this.lastFilesOverwritten,
      lastFilesKeptBoth: lastFilesKeptBoth ?? this.lastFilesKeptBoth,
      lastBytesRestored: lastBytesRestored ?? this.lastBytesRestored,
    );
  }
}

final restoreRepositoryProvider = Provider<RestoreRepository>((ref) {
  return RestoreRepository.instance;
});

class RestoreNotifier extends StateNotifier<RestoreState> {
  RestoreNotifier(this._repository, this._historyNotifier, this._readSettings)
    : super(const RestoreState());

  final RestoreRepository _repository;
  final HistoryNotifier _historyNotifier;
  final AppSettingsModel Function() _readSettings;
  RestoreCancellationToken? _activeCancellationToken;

  Future<RestorePreviewResult> previewFiles({
    required FtpServerModel ftpServer,
    required String remoteFolderPath,
    required String localFolderPath,
    required RestoreConflictRule conflictRule,
    required RestoreFilterOptions filterOptions,
  }) async {
    state = state.copyWith(
      status: RestoreStatus.previewing,
      message: 'Scanning remote backup folder...',
      previewFiles: const [],
      conflictPreview: const RestoreConflictPreviewResult.empty(),
    );

    final result = await _repository.previewFiles(
      ftpServer: ftpServer,
      remoteFolderPath: remoteFolderPath,
      filterOptions: filterOptions,
    );
    final conflictPreview = result.success
        ? await _repository.previewLocalConflicts(
            files: result.files,
            localFolderPath: localFolderPath,
            conflictRule: conflictRule,
          )
        : const RestoreConflictPreviewResult.empty();
    state = state.copyWith(
      status: result.success ? RestoreStatus.ready : RestoreStatus.failed,
      message: _previewMessage(result, conflictPreview),
      previewFiles: result.files,
      conflictPreview: conflictPreview,
    );

    return result;
  }

  Future<void> refreshConflictPreview({
    required String localFolderPath,
    required RestoreConflictRule conflictRule,
  }) async {
    if (state.previewFiles.isEmpty) {
      state = state.copyWith(
        conflictPreview: const RestoreConflictPreviewResult.empty(),
      );
      return;
    }

    final conflictPreview = await _repository.previewLocalConflicts(
      files: state.previewFiles,
      localFolderPath: localFolderPath,
      conflictRule: conflictRule,
    );
    state = state.copyWith(
      message: _previewMessage(
        RestorePreviewResult(
          success: true,
          message: 'Preview found ${state.previewFiles.length} file(s).',
          files: state.previewFiles,
        ),
        conflictPreview,
      ),
      conflictPreview: conflictPreview,
    );
  }

  void clearPreview(String message) {
    state = state.copyWith(
      status: RestoreStatus.idle,
      message: message,
      previewFiles: const [],
      conflictPreview: const RestoreConflictPreviewResult.empty(),
      currentFileIndex: 0,
      totalFiles: 0,
      currentFilePath: '',
      cancelRequested: false,
    );
  }

  Future<void> cancelRestore() async {
    final token = _activeCancellationToken;
    if (token == null || token.isCancelled) {
      return;
    }

    token.cancel();
    const message = 'Cancelling restore after the current file...';
    state = state.copyWith(
      status: RestoreStatus.cancelling,
      message: message,
      cancelRequested: true,
    );
    if (_readSettings().showForegroundNotifications) {
      await RestoreForegroundServiceBridge.update(message: message);
    }
  }

  Future<RestoreRunResult> runRestore({
    required FtpServerModel ftpServer,
    required String remoteFolderPath,
    required String localFolderPath,
    required RestoreConflictRule conflictRule,
    required RestoreFilterOptions filterOptions,
  }) async {
    state = state.copyWith(
      status: RestoreStatus.running,
      message: 'Restore is running...',
      currentFileIndex: 0,
      totalFiles: state.conflictPreview.filesToRestore,
      currentFilePath: '',
      cancelRequested: false,
    );
    final cancellationToken = RestoreCancellationToken();
    _activeCancellationToken = cancellationToken;

    var foregroundStarted = false;
    if (_readSettings().showForegroundNotifications) {
      foregroundStarted = await RestoreForegroundServiceBridge.start(
        message: 'Preparing restore...',
      );
    }

    RestoreRunResult result;
    try {
      result = await _repository.runRestore(
        ftpServer: ftpServer,
        remoteFolderPath: remoteFolderPath,
        localFolderPath: localFolderPath,
        conflictRule: conflictRule,
        filterOptions: filterOptions,
        cancellationToken: cancellationToken,
        onProgress: (progress) async {
          final message =
              'Processed ${progress.currentFileIndex}/${progress.totalFiles}: ${progress.currentFilePath}';
          state = state.copyWith(
            status: cancellationToken.isCancelled
                ? RestoreStatus.cancelling
                : RestoreStatus.running,
            message: message,
            currentFileIndex: progress.currentFileIndex,
            totalFiles: progress.totalFiles,
            currentFilePath: progress.currentFilePath,
            lastFilesRestored: progress.filesRestored,
            lastFilesSkipped: progress.filesSkipped,
            lastFilesOverwritten: progress.filesOverwritten,
            lastFilesKeptBoth: progress.filesKeptBoth,
            lastBytesRestored: progress.bytesRestored,
            cancelRequested: cancellationToken.isCancelled,
          );

          if (foregroundStarted) {
            await RestoreForegroundServiceBridge.update(message: message);
          }
        },
      );
    } catch (_) {
      result = const RestoreRunResult(
        success: false,
        message: 'Restore failed unexpectedly.',
        filesRestored: 0,
        filesSkipped: 0,
        filesOverwritten: 0,
        filesKeptBoth: 0,
        bytesRestored: 0,
      );
    } finally {
      _activeCancellationToken = null;
      if (foregroundStarted) {
        await RestoreForegroundServiceBridge.stop();
      }
    }

    state = state.copyWith(
      status: result.cancelled
          ? RestoreStatus.cancelled
          : result.success
          ? RestoreStatus.success
          : RestoreStatus.failed,
      message: result.message,
      currentFileIndex: result.filesRestored + result.filesSkipped,
      totalFiles: result.filesRestored + result.filesSkipped,
      currentFilePath: '',
      cancelRequested: false,
      lastFilesRestored: result.filesRestored,
      lastFilesSkipped: result.filesSkipped,
      lastFilesOverwritten: result.filesOverwritten,
      lastFilesKeptBoth: result.filesKeptBoth,
      lastBytesRestored: result.bytesRestored,
    );
    await _writeHistory(
      ftpServer: ftpServer,
      remoteFolderPath: remoteFolderPath,
      localFolderPath: localFolderPath,
      result: result,
    );

    return result;
  }

  Future<void> _writeHistory({
    required FtpServerModel ftpServer,
    required String remoteFolderPath,
    required String localFolderPath,
    required RestoreRunResult result,
  }) async {
    await _historyNotifier.addEntry(
      HistoryEntryModel(
        id: 'restore-${DateTime.now().microsecondsSinceEpoch}',
        operationType: HistoryOperationType.restore,
        status: result.success
            ? HistoryEntryStatus.success
            : result.cancelled
            ? HistoryEntryStatus.cancelled
            : HistoryEntryStatus.failed,
        title: 'Restore from ${ftpServer.name}',
        message: result.message,
        sourcePath: '${ftpServer.name}:$remoteFolderPath',
        targetPath: localFolderPath,
        relatedId: ftpServer.id,
        createdAt: DateTime.now(),
        filesChanged: result.filesRestored,
        bytesChanged: result.bytesRestored,
        fileReports: _fileReports(result),
      ),
    );
  }

  List<HistoryFileReportItem> _fileReports(RestoreRunResult result) {
    return [
      ...result.restoredRelativePaths.map(
        (relativePath) => HistoryFileReportItem(
          relativePath: relativePath,
          action: 'download',
        ),
      ),
      ...result.skippedRelativePaths.map(
        (relativePath) => HistoryFileReportItem(
          relativePath: relativePath,
          action: 'skip',
          message: 'Existing local file',
        ),
      ),
      ...result.overwrittenRelativePaths.map(
        (relativePath) => HistoryFileReportItem(
          relativePath: relativePath,
          action: 'overwrite',
        ),
      ),
      ...result.keptBothRelativePaths.map(
        (relativePath) =>
            HistoryFileReportItem(relativePath: relativePath, action: 'copy'),
      ),
    ];
  }

  String _previewMessage(
    RestorePreviewResult result,
    RestoreConflictPreviewResult conflictPreview,
  ) {
    if (!result.success || result.files.isEmpty) {
      return result.message;
    }

    if (conflictPreview.existingConflicts == 0) {
      return '${result.message} No local conflicts.';
    }

    return '${result.message} ${conflictPreview.existingConflicts} local conflict(s) found.';
  }
}

final restoreProvider = StateNotifierProvider<RestoreNotifier, RestoreState>((
  ref,
) {
  final repository = ref.watch(restoreRepositoryProvider);
  final historyNotifier = ref.watch(historyProvider.notifier);
  return RestoreNotifier(
    repository,
    historyNotifier,
    () => ref.read(appSettingsProvider),
  );
});
