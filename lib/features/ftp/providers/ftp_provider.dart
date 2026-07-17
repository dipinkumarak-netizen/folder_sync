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

  void addServer(FtpServerModel server) {
    _repository.add(server);
    refresh();
  }

  void deleteServer(String id) {
    _repository.remove(id);
    refresh();
  }

  void updateServer(FtpServerModel server) {
    _repository.update(server);
    refresh();
  }

  void clearServers() {
    _repository.clear();
    refresh();
  }
}

final ftpServerProvider =
    StateNotifierProvider<FtpServerNotifier, List<FtpServerModel>>((ref) {
  final repository = ref.watch(ftpRepositoryProvider);
  return FtpServerNotifier(repository);
});
