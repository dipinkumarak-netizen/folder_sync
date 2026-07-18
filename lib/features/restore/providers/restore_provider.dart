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

enum RestoreStatus { idle, previewing, ready, running, success, failed }

class RestoreState {
  final RestoreStatus status;
  final String message;
  final List<RestoreFileEntry> previewFiles;
  final int lastFilesRestored;
  final int lastFilesSkipped;
  final int lastFilesOverwritten;
  final int lastFilesKeptBoth;
  final int lastBytesRestored;

  const RestoreState({
    this.status = RestoreStatus.idle,
    this.message = 'Select a backup folder to restore.',
    this.previewFiles = const [],
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

  Future<RestorePreviewResult> previewFiles({
    required FtpServerModel ftpServer,
    required String remoteFolderPath,
  }) async {
    state = state.copyWith(
      status: RestoreStatus.previewing,
      message: 'Scanning remote backup folder...',
      previewFiles: const [],
    );

    final result = await _repository.previewFiles(
      ftpServer: ftpServer,
      remoteFolderPath: remoteFolderPath,
    );
    state = state.copyWith(
      status: result.success ? RestoreStatus.ready : RestoreStatus.failed,
      message: result.message,
      previewFiles: result.files,
    );

    return result;
  }

  Future<RestoreRunResult> runRestore({
    required FtpServerModel ftpServer,
    required String remoteFolderPath,
    required String localFolderPath,
    required RestoreConflictRule conflictRule,
  }) async {
    state = state.copyWith(
      status: RestoreStatus.running,
      message: 'Restore is running...',
    );

    var foregroundStarted = false;
    if (_readSettings().showForegroundNotifications) {
      foregroundStarted = await RestoreForegroundServiceBridge.start();
    }

    RestoreRunResult result;
    try {
      result = await _repository.runRestore(
        ftpServer: ftpServer,
        remoteFolderPath: remoteFolderPath,
        localFolderPath: localFolderPath,
        conflictRule: conflictRule,
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
      if (foregroundStarted) {
        await RestoreForegroundServiceBridge.stop();
      }
    }

    state = state.copyWith(
      status: result.success ? RestoreStatus.success : RestoreStatus.failed,
      message: result.message,
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
            : HistoryEntryStatus.failed,
        title: 'Restore from ${ftpServer.name}',
        message: result.message,
        sourcePath: '${ftpServer.name}:$remoteFolderPath',
        targetPath: localFolderPath,
        relatedId: ftpServer.id,
        createdAt: DateTime.now(),
        filesChanged: result.filesRestored,
        bytesChanged: result.bytesRestored,
      ),
    );
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
