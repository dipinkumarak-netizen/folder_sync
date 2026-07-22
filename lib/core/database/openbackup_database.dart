import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

/// ===============================================================
/// OpenBackup
/// File : openbackup_database.dart
/// Version : 1.0.0
/// Description : Shared SQLite database service for local app persistence.
/// ===============================================================

class OpenBackupDatabase {
  OpenBackupDatabase._();

  static final OpenBackupDatabase instance = OpenBackupDatabase._();

  static const String ftpServersTable = 'ftp_servers';

  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }

    final databasePath = await getDatabasesPath();
    final db = await openDatabase(
      path.join(databasePath, 'openbackup.db'),
      version: 1,
      onCreate: (database, version) async {
        await _createFtpServersTable(database);
      },
    );

    _database = db;
    return db;
  }

  Future<void> _createFtpServersTable(Database database) async {
    await database.execute('''
      CREATE TABLE $ftpServersTable (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        host TEXT NOT NULL,
        port INTEGER NOT NULL,
        username TEXT NOT NULL,
        password TEXT NOT NULL,
        remote_path TEXT NOT NULL,
        is_anonymous INTEGER NOT NULL,
        is_favorite INTEGER NOT NULL,
        use_passive_mode INTEGER NOT NULL,
        support_utf8 INTEGER NOT NULL,
        protocol TEXT NOT NULL
      )
    ''');
  }
}
