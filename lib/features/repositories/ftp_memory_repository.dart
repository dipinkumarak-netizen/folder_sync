import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:ftpconnect/ftpconnect.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/openbackup_database.dart';
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
      final database = await OpenBackupDatabase.instance.database;
      final storedServers = await _loadFromDatabase(database);
      if (storedServers.isNotEmpty) {
        _servers
          ..clear()
          ..addAll(storedServers);
        return;
      }

      final legacyServers = await _loadFromJson();
      if (legacyServers.isEmpty) {
        return;
      }

      _servers
        ..clear()
        ..addAll(legacyServers);
      await _saveToDatabase(database);
    } catch (_) {
      final legacyServers = await _loadFromJson();
      _servers
        ..clear()
        ..addAll(legacyServers);
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
    if (server.protocol == ServerProtocol.sftp) {
      return _testSftpConnection(server);
    }

    final ftpConnect = FTPConnect(
      server.host,
      port: server.port,
      user: server.isAnonymous ? 'anonymous' : server.username,
      pass: server.isAnonymous ? '' : server.password,
      timeout: 10,
    );

    var connected = false;
    try {
      // The current ftpconnect library might not have supportUTF8 parameter in connect()
      // or it might be handled internally. If the library doesn't support it,
      // we ignore the flag to prevent build errors.
      connected = await ftpConnect.connect();
      if (!connected) {
        return const FtpConnectionTestResult(
          success: false,
          message: 'Could not connect to the FTP server. Check host and port.',
        );
      }

      // Some modems/routers land the user in a specific folder.
      // Let's check where we are.
      try {
        await ftpConnect.currentDirectory();
      } catch (_) {}

      final remotePath = server.remotePath.trim();
      if (remotePath.isEmpty || remotePath == '/' || remotePath == '.') {
        return const FtpConnectionTestResult(
          success: true,
          message: 'FTP connection successful.',
        );
      }

      await _changeRemoteDirectory(ftpConnect, remotePath);
      return const FtpConnectionTestResult(
        success: true,
        message: 'FTP connection successful.',
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
        try {
          await ftpConnect.disconnect();
        } catch (_) {}
      }
    }
  }

  Future<FtpRemoteFolderListResult> listRemoteFolders({
    required FtpServerModel server,
    required String remotePath,
  }) async {
    if (server.protocol == ServerProtocol.sftp) {
      return _listSftpFolders(server: server, remotePath: remotePath);
    }

    var ftpConnect = _createFtpClient(server, timeout: 15);

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

      // Attempt to change directory. If it fails, we might already be there
      // or the server has a weird root.
      try {
        await _changeRemoteDirectory(ftpConnect, currentPath);
      } catch (e) {
        // If we are at root and CWD / fails, ignore it for routers
        if (currentPath != '/') rethrow;
      }

      List<FTPEntry> entries;
      try {
        entries = await ftpConnect.listDirectoryContent();
      } catch (_) {
        // Older router/modem FTP servers (including Huawei bftpd) commonly
        // reject MLSD with a 500 response. Reconnect before retrying because
        // a failed data-channel command can leave the FTP session unusable.
        await ftpConnect.disconnect();
        connected = false;

        ftpConnect = _createFtpClient(server, timeout: 15)
          ..listCommand = ListCommand.list;
        connected = await ftpConnect.connect();
        if (!connected) {
          throw StateError('Could not reconnect to the FTP server.');
        }

        try {
          await _changeRemoteDirectory(ftpConnect, currentPath);
        } catch (_) {
          if (currentPath != '/') rethrow;
        }
        entries = await ftpConnect.listDirectoryContent();
      }
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

  FTPConnect _createFtpClient(FtpServerModel server, {required int timeout}) {
    return FTPConnect(
      server.host,
      port: server.port,
      user: server.isAnonymous ? 'anonymous' : server.username,
      pass: server.isAnonymous ? '' : server.password,
      timeout: timeout,
    );
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
      final database = await OpenBackupDatabase.instance.database;
      await _saveToDatabase(database);
      return;
    } catch (_) {
      await _saveToJson();
    }
  }

  Future<List<FtpServerModel>> _loadFromDatabase(Database database) async {
    final rows = await database.query(
      OpenBackupDatabase.ftpServersTable,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows
        .map(_serverFromRow)
        .where((server) => server.id.isNotEmpty)
        .toList();
  }

  Future<void> _saveToDatabase(Database database) async {
    await database.transaction((transaction) async {
      await transaction.delete(OpenBackupDatabase.ftpServersTable);
      for (final server in _servers) {
        await transaction.insert(
          OpenBackupDatabase.ftpServersTable,
          _serverToRow(server),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<FtpServerModel>> _loadFromJson() async {
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
          .map(FtpServerModel.fromJson)
          .where((server) => server.id.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveToJson() async {
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

  Map<String, Object?> _serverToRow(FtpServerModel server) {
    return {
      'id': server.id,
      'name': server.name,
      'host': server.host,
      'port': server.port,
      'username': server.username,
      'password': server.password,
      'remote_path': server.remotePath,
      'is_anonymous': server.isAnonymous ? 1 : 0,
      'is_favorite': server.isFavorite ? 1 : 0,
      'use_passive_mode': server.usePassiveMode ? 1 : 0,
      'support_utf8': server.supportUtf8 ? 1 : 0,
      'protocol': server.protocol.name,
    };
  }

  FtpServerModel _serverFromRow(Map<String, Object?> row) {
    return FtpServerModel(
      id: row['id'] as String? ?? '',
      name: row['name'] as String? ?? '',
      host: row['host'] as String? ?? '',
      port: row['port'] as int? ?? 21,
      username: row['username'] as String? ?? '',
      password: row['password'] as String? ?? '',
      remotePath: row['remote_path'] as String? ?? '/',
      isAnonymous: _boolFromInt(row['is_anonymous']),
      isFavorite: _boolFromInt(row['is_favorite']),
      usePassiveMode: _boolFromInt(row['use_passive_mode'], fallback: true),
      supportUtf8: _boolFromInt(row['support_utf8'], fallback: true),
      protocol: ServerProtocol.values.firstWhere(
        (protocol) => protocol.name == row['protocol'],
        orElse: () => ServerProtocol.ftp,
      ),
    );
  }

  bool _boolFromInt(Object? value, {bool fallback = false}) {
    if (value is int) {
      return value == 1;
    }

    return fallback;
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
      // For routers, try to go to the real root, but don't crash if it fails
      try {
        await ftpConnect.changeDirectory('/');
      } catch (_) {}
      return;
    }

    // Try absolute path first
    if (normalizedPath.startsWith('/')) {
      try {
        final changed = await ftpConnect.changeDirectory(normalizedPath);
        if (changed) {
          return;
        }
      } catch (_) {
        // Fallback to stepping through
      }

      // If absolute fails, go to root and then step
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

  // ==========================================================
  // SFTP Helpers
  // ==========================================================

  Future<FtpConnectionTestResult> _testSftpConnection(
    FtpServerModel server,
  ) async {
    SSHClient? client;
    try {
      client = SSHClient(
        await SSHSocket.connect(
          server.host,
          server.port,
          timeout: const Duration(seconds: 10),
        ),
        username: server.username,
        onPasswordRequest: () => server.password,
      );

      final sftp = await client.sftp();

      final remotePath = server.remotePath.trim();
      if (remotePath.isNotEmpty && remotePath != '/' && remotePath != '.') {
        await sftp.stat(remotePath);
      }

      client.close();
      return const FtpConnectionTestResult(
        success: true,
        message: 'SFTP connection successful.',
      );
    } catch (error) {
      client?.close();
      return FtpConnectionTestResult(
        success: false,
        message: FailureMessage.from(
          error,
          operation: 'SFTP connection test',
          fallback: 'Could not connect to the SFTP server.',
        ),
      );
    }
  }

  Future<FtpRemoteFolderListResult> _listSftpFolders({
    required FtpServerModel server,
    required String remotePath,
  }) async {
    SSHClient? client;
    try {
      client = SSHClient(
        await SSHSocket.connect(
          server.host,
          server.port,
          timeout: const Duration(seconds: 15),
        ),
        username: server.username,
        onPasswordRequest: () => server.password,
      );

      final sftp = await client.sftp();
      final currentPath = _normalizeRemotePath(remotePath);

      final entries = await sftp.listdir(currentPath);
      final folders =
          entries
              .where((entry) => entry.attr.isDirectory)
              .map(
                (entry) => FtpRemoteFolderEntry(
                  name: entry.filename,
                  path: _joinRemotePath(currentPath, entry.filename),
                ),
              )
              .where((entry) => entry.name != '.' && entry.name != '..')
              .toList()
            ..sort((first, second) => first.name.compareTo(second.name));

      client.close();
      return FtpRemoteFolderListResult(
        success: true,
        message: folders.isEmpty
            ? 'No folders found in this remote folder.'
            : 'Folders loaded.',
        currentPath: currentPath,
        folders: folders,
      );
    } catch (error) {
      client?.close();
      return FtpRemoteFolderListResult(
        success: false,
        message: FailureMessage.from(
          error,
          operation: 'Remote SFTP folder browser',
          fallback: 'Could not list SFTP folders.',
        ),
        currentPath: _normalizeRemotePath(remotePath),
        folders: const [],
      );
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
