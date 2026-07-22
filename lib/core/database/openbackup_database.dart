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
  static const String syncRulesTable = 'sync_rules';
  static const String historyEntriesTable = 'history_entries';

  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }

    final databasePath = await getDatabasesPath();
    final db = await openDatabase(
      path.join(databasePath, 'openbackup.db'),
      version: 4,
      onCreate: (database, version) async {
        await _createFtpServersTable(database);
        await _createBackupJobsTable(database);
        await _createSyncRulesTable(database);
        await _createHistoryEntriesTable(database);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createBackupJobsTable(database);
        }
        if (oldVersion < 3) {
          await _createSyncRulesTable(database);
        }
        if (oldVersion < 4) {
          await _createHistoryEntriesTable(database);
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

  Future<void> _createSyncRulesTable(Database database) async {
    await database.execute('''
      CREATE TABLE $syncRulesTable (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        local_folder_path TEXT NOT NULL,
        ftp_server_id TEXT NOT NULL,
        remote_folder_path TEXT NOT NULL,
        enabled INTEGER NOT NULL,
        direction TEXT NOT NULL,
        conflict_rule TEXT NOT NULL,
        delete_rule TEXT NOT NULL,
        trigger_rule TEXT NOT NULL,
        sync_subfolders INTEGER NOT NULL,
        include_hidden_files INTEGER NOT NULL,
        run_on_wifi_only INTEGER NOT NULL,
        run_only_while_charging INTEGER NOT NULL,
        home_wifi_name TEXT NOT NULL,
        include_patterns TEXT NOT NULL,
        exclude_patterns TEXT NOT NULL,
        max_file_size_mb INTEGER,
        status TEXT NOT NULL,
        last_run_at TEXT,
        last_message TEXT NOT NULL,
        last_files_changed INTEGER NOT NULL,
        total_files_changed INTEGER NOT NULL,
        total_bytes_changed INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createHistoryEntriesTable(Database database) async {
    await database.execute('''
      CREATE TABLE $historyEntriesTable (
        id TEXT PRIMARY KEY,
        operation_type TEXT NOT NULL,
        status TEXT NOT NULL,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        source_path TEXT NOT NULL,
        target_path TEXT NOT NULL,
        related_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        files_changed INTEGER NOT NULL,
        bytes_changed INTEGER NOT NULL,
        file_reports TEXT NOT NULL
      )
    ''');
  }
}
