import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:ftpconnect/ftpconnect.dart';
import 'package:path_provider/path_provider.dart';

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
      final file = await _storageFile();
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
        return false;
      }

      final remotePath = server.remotePath.trim();
      if (remotePath.isEmpty || remotePath == '/') {
        return true;
      }

      return ftpConnect.changeDirectory(remotePath);
    } catch (_) {
      return false;
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
      final file = await _storageFile().timeout(const Duration(seconds: 1));
      final encoded = jsonEncode(
        _servers.map((server) => server.toJson()).toList(),
      );
      await file.writeAsString(encoded);
    } catch (_) {
      return;
    }
  }
}
