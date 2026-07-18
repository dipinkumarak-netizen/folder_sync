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

    if (error is FileSystemException ||
        lowerText.contains('permission denied') ||
        lowerText.contains('access is denied')) {
      return '$operation could not access a local file or folder. Check storage permissions.';
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
