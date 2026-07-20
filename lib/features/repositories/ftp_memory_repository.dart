import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:ftpconnect/ftpconnect.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../core/utils/failure_message.dart';
import '../ftp/models/ftp_server_model.dart';

/// ===============================================================
/// OpenBackup
/// File : ftp_memory_repository.dart
/// Version : 1.0.0
/// Description : In-memory repository for FTP servers.
/// Change Log:
/// 1.0.0 - Initial implementation.
/// ===============================================================

class FtpMemoryRepository {
  FtpMemoryRepository._();

  static final FtpMemoryRepository instance = FtpMemoryRepository._();

  final List<FtpServerModel> _servers = [];
  bool _loaded = false;

  /// Returns all FTP servers.
  UnmodifiableListView<FtpServerModel> getAll() {
    return UnmodifiableListView(_servers);
  }

  /// Loads saved FTP servers from local storage.
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

      _servers
        ..clear()
        ..addAll(
          decoded
              .whereType<Map<String, dynamic>>()
              .map(FtpServerModel.fromJson)
              .where((server) => server.id.isNotEmpty),
        );
    } catch (_) {
      return;
    }
  }

  /// Adds a new FTP server.
  void add(FtpServerModel server) {
    _servers.add(server);
    unawaited(_save());
  }

  /// Removes a server by id.
  bool remove(String id) {
    final exists = _servers.any((e) => e.id == id);
    _servers.removeWhere((e) => e.id == id);
    unawaited(_save());
    return exists;
  }

  /// Updates an existing server.
  bool update(FtpServerModel server) {
    final index = _servers.indexWhere((e) => e.id == server.id);

    if (index == -1) {
      return false;
    }

    _servers[index] = server;
    unawaited(_save());
    return true;
  }

  /// Finds a server by id.
  FtpServerModel? findById(String id) {
    try {
      return _servers.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Removes all servers.
  void clear() {
    _servers.clear();
    unawaited(_save());
  }

  /// Number of configured servers.
  int count() {
    return _servers.length;
  }

  /// Returns true if repository has no servers.
  bool isEmpty() {
    return _servers.isEmpty;
  }

  /// Tests whether the FTP server can be reached and authenticated.
  Future<bool> testConnection(FtpServerModel server) async {
    final result = await testConnectionDetailed(server);
    return result.success;
  }

  Future<FtpConnectionTestResult> testConnectionDetailed(
    FtpServerModel server,
  ) async {
    final ftpConnect = FTPConnect(
      server.host,
      port: server.port,
      user: server.isAnonymous ? 'anonymous' : server.username,
      pass: server.isAnonymous ? '' : server.password,
      timeout: 10,
    );

    var connected = false;
    try {
      connected = await ftpConnect.connect();
      if (!connected) {
        return const FtpConnectionTestResult(
          success: false,
          message: 'Could not connect to the FTP server. Check host and port.',
        );
      }

      final remotePath = server.remotePath.trim();
      if (remotePath.isEmpty || remotePath == '/') {
        return const FtpConnectionTestResult(
          success: true,
          message: 'FTP connection successful.',
        );
      }

      final changed = await ftpConnect.changeDirectory(remotePath);
      return FtpConnectionTestResult(
        success: changed,
        message: changed
            ? 'FTP connection successful.'
            : 'FTP connected, but the remote folder was not available.',
      );
    } catch (error) {
      return FtpConnectionTestResult(
        success: false,
        message: FailureMessage.from(
          error,
          operation: 'FTP connection test',
          fallback: 'Could not connect to the FTP server.',
        ),
      );
    } finally {
      if (connected) {
        await ftpConnect.disconnect();
      }
    }
  }

  Future<FtpRemoteFolderListResult> listRemoteFolders({
    required FtpServerModel server,
    required String remotePath,
  }) async {
    final ftpConnect = FTPConnect(
      server.host,
      port: server.port,
      user: server.isAnonymous ? 'anonymous' : server.username,
      pass: server.isAnonymous ? '' : server.password,
      timeout: 15,
    );

    var connected = false;
    try {
      connected = await ftpConnect.connect();
      if (!connected) {
        return const FtpRemoteFolderListResult(
          success: false,
          message: 'Could not connect to the FTP server.',
          currentPath: '/',
          folders: [],
        );
      }

      final currentPath = _normalizeRemotePath(remotePath);
      await _changeRemoteDirectory(ftpConnect, currentPath);
      final entries = await ftpConnect.listDirectoryContent();
      final folders =
          entries
              .where((entry) => entry.type == FTPEntryType.dir)
              .map(
                (entry) => FtpRemoteFolderEntry(
                  name: entry.name,
                  path: _joinRemotePath(currentPath, entry.name),
                ),
              )
              .where(
                (entry) =>
                    entry.name.isNotEmpty &&
                    entry.name != '.' &&
                    entry.name != '..',
              )
              .toList()
            ..sort((first, second) => first.name.compareTo(second.name));

      return FtpRemoteFolderListResult(
        success: true,
        message: folders.isEmpty
            ? 'No folders found in this remote folder.'
            : 'Folders loaded.',
        currentPath: currentPath,
        folders: folders,
      );
    } catch (error) {
      return FtpRemoteFolderListResult(
        success: false,
        message: FailureMessage.from(
          error,
          operation: 'Remote folder browser',
          fallback: 'Could not list remote folders.',
        ),
        currentPath: _normalizeRemotePath(remotePath),
        folders: const [],
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

    return File('${storageDirectory.path}/ftp_servers.json');
  }

  Future<void> _save() async {
    try {
      final file = await _storageFile();
      final encoded = jsonEncode(
        _servers.map((server) => server.toJson()).toList(),
      );
      await file.writeAsString(encoded);
    } catch (_) {
      return;
    }
  }

  String _normalizeRemotePath(String remotePath) {
    final trimmed = remotePath.trim();
    if (trimmed.isEmpty) {
      return '/';
    }

    final normalized = path.posix.normalize(trimmed);
    return normalized == '.' ? '/' : normalized;
  }

  String _joinRemotePath(String currentPath, String folderName) {
    final safeName = folderName.trim();
    if (currentPath == '/' || currentPath.isEmpty) {
      return '/$safeName';
    }

    return path.posix.normalize(path.posix.join(currentPath, safeName));
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

class FtpConnectionTestResult {
  final bool success;
  final String message;

  const FtpConnectionTestResult({required this.success, required this.message});
}

class FtpRemoteFolderEntry {
  final String name;
  final String path;

  const FtpRemoteFolderEntry({required this.name, required this.path});
}

class FtpRemoteFolderListResult {
  final bool success;
  final String message;
  final String currentPath;
  final List<FtpRemoteFolderEntry> folders;

  const FtpRemoteFolderListResult({
    required this.success,
    required this.message,
    required this.currentPath,
    required this.folders,
  });
}
