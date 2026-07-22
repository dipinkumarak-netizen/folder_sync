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
  static const String backupJobsTable = 'backup_jobs';

  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }

    final databasePath = await getDatabasesPath();
    final db = await openDatabase(
      path.join(databasePath, 'openbackup.db'),
      version: 2,
      onCreate: (database, version) async {
        await _createFtpServersTable(database);
        await _createBackupJobsTable(database);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createBackupJobsTable(database);
        }
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

  Future<void> _createBackupJobsTable(Database database) async {
    await database.execute('''
      CREATE TABLE $backupJobsTable (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        local_folder_path TEXT NOT NULL,
        ftp_server_id TEXT NOT NULL,
        remote_folder_path TEXT NOT NULL,
        enabled INTEGER NOT NULL,
        schedule_rule TEXT NOT NULL,
        run_on_wifi_only INTEGER NOT NULL,
        run_only_while_charging INTEGER NOT NULL,
        compress_before_upload INTEGER NOT NULL,
        home_wifi_name TEXT NOT NULL,
        status TEXT NOT NULL,
        last_run_at TEXT,
        last_message TEXT NOT NULL,
        last_files_backed_up INTEGER NOT NULL,
        total_files_backed_up INTEGER NOT NULL,
        total_bytes_backed_up INTEGER NOT NULL,
        backed_up_relative_paths TEXT NOT NULL
      )
    ''');
  }
}
