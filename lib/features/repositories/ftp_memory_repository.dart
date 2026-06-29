import 'dart:collection';

import '../models/ftp_server_model.dart';

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

  /// Returns all FTP servers.
  UnmodifiableListView<FtpServerModel> getAll() {
    return UnmodifiableListView(_servers);
  }

  /// Adds a new FTP server.
  void add(FtpServerModel server) {
    _servers.add(server);
  }

  /// Removes a server by id.
  bool remove(String id) {
    return _servers.removeWhere((e) => e.id == id) > 0;
  }

  /// Updates an existing server.
  bool update(FtpServerModel server) {
    final index = _servers.indexWhere((e) => e.id == server.id);

    if (index == -1) {
      return false;
    }

    _servers[index] = server;
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
  }

  /// Number of configured servers.
  int count() {
    return _servers.length;
  }

  /// Returns true if repository has no servers.
  bool isEmpty() {
    return _servers.isEmpty;
  }
}