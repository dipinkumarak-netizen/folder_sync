// ===============================================================
// OpenBackup
// File : ftp_server_model.dart
// Version : 1.0.0
// Description : FTP Server Model
// ===============================================================

class FtpServerModel {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final String password;
  final String remotePath;
  final bool isAnonymous;
  final bool isFavorite;

  const FtpServerModel({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.remotePath,
    this.isAnonymous = false,
    this.isFavorite = false,
  });

  FtpServerModel copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? username,
    String? password,
    String? remotePath,
    bool? isAnonymous,
    bool? isFavorite,
  }) {
    return FtpServerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      remotePath: remotePath ?? this.remotePath,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'username': username,
      'password': password,
      'remotePath': remotePath,
      'isAnonymous': isAnonymous,
      'isFavorite': isFavorite,
    };
  }

  factory FtpServerModel.fromJson(Map<String, dynamic> json) {
    return FtpServerModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      host: json['host'] as String? ?? '',
      port: json['port'] as int? ?? 21,
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      remotePath: json['remotePath'] as String? ?? '/',
      isAnonymous: json['isAnonymous'] as bool? ?? false,
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }
}
