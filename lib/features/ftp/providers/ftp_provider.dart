import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ftp_server_model.dart';
import '../../repositories/ftp_memory_repository.dart';

/// ===============================================================
/// OpenBackup
/// File : ftp_provider.dart
/// Version : 1.0.0
/// Description : Riverpod provider for FTP servers.
/// Change Log:
/// 1.0.0 - Initial implementation.
/// ===============================================================

final ftpRepositoryProvider = Provider<FtpMemoryRepository>((ref) {
  return FtpMemoryRepository.instance;
});

class FtpServerNotifier extends StateNotifier<List<FtpServerModel>> {
  FtpServerNotifier(this._repository) : super(_repository.getAll().toList());

  final FtpMemoryRepository _repository;

  void refresh() {
    state = _repository.getAll().toList();
  }

  Future<void> loadServers() async {
    await _repository.load();
    refresh();
  }

  Future<void> addServer(FtpServerModel server) async {
    _repository.add(server);
    refresh();
  }

  Future<void> deleteServer(String id) async {
    _repository.remove(id);
    refresh();
  }

  Future<void> updateServer(FtpServerModel server) async {
    _repository.update(server);
    refresh();
  }

  Future<void> clearServers() async {
    _repository.clear();
    refresh();
  }

  Future<bool> testConnection(FtpServerModel server) {
    return _repository.testConnection(server);
  }
}

final ftpServerProvider =
    StateNotifierProvider<FtpServerNotifier, List<FtpServerModel>>((ref) {
      final repository = ref.watch(ftpRepositoryProvider);
      return FtpServerNotifier(repository);
    });

final ftpServerLoadProvider = FutureProvider<void>((ref) async {
  await ref.read(ftpServerProvider.notifier).loadServers();
});
