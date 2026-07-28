import 'dart:async';
import 'dart:io';

/// ===============================================================
/// OpenBackup
/// File : failure_message.dart
/// Version : 1.0.0
/// Description : User-facing operation failure message formatter.
/// ===============================================================

class FailureMessage {
  FailureMessage._();

  static String from(
    Object error, {
    required String operation,
    String? fallback,
    bool includeDetails = false,
  }) {
    final text = error.toString();
    final lowerText = text.toLowerCase();

    if (error is TimeoutException || lowerText.contains('timed out')) {
      return '$operation timed out. Check the network and FTP server address.';
    }

    if (error is SocketException ||
        lowerText.contains('socket') ||
        lowerText.contains('host lookup') ||
        lowerText.contains('connection refused') ||
        lowerText.contains('network is unreachable')) {
      return '$operation could not reach the FTP server. Check host, port, and network.';
    }

    // SFTP libraries can also throw FileSystemException/"permission denied"
    // for a remote path. Only classify it as local storage access when the
    // caller explicitly says the local filesystem is being accessed.
    if (error is FileSystemException && !operation.startsWith('SFTP')) {
      return '$operation could not access a local file or folder. Check storage permissions.';
    }

    if (includeDetails &&
        (lowerText.contains('permission denied') ||
            lowerText.contains('access is denied') ||
            error is FileSystemException)) {
      return '$operation failed: ${error.toString()}';
    }

    if (lowerText.contains('login') ||
        lowerText.contains('auth') ||
        lowerText.contains('530')) {
      return '$operation failed because the FTP login was rejected.';
    }

    if (lowerText.contains('could not open remote folder') ||
        lowerText.contains('550') ||
        lowerText.contains('no such file')) {
      return '$operation failed because the remote folder or file was not available.';
    }

    if (error is StateError && error.message.isNotEmpty) {
      return '$operation failed. ${error.message}';
    }

    return fallback ?? '$operation failed. Check settings and try again.';
  }
}
