# OpenBackup

OpenBackup is a Flutter-based Android app for backing up local folders to FTP
or SFTP servers, restoring files, and synchronizing folders with scheduled or
instant triggers.

The project is currently an active pre-release app. It is usable for debug
builds, but long-term SQLite persistence is still planned work.

## Current Features

- FTP and SFTP connection management with connection testing.
- Remote folder picker with manual path entry for devices that do not expose
  folders cleanly through FTP listings.
- Manual backup of new local files only.
- Instant backup trigger when files are added to watched folders.
- Scheduled backup rules: hourly, daily, and home Wi-Fi.
- Manual, scheduled, and instant sync rules.
- Sync directions: upload only, download only, two-way, mirror local to remote,
  and mirror remote to local.
- Sync conflict rules: newer wins, local wins, remote wins, keep both, and skip.
- Protected delete preview before destructive sync delete operations.
- Remote file diffing based on size and modified timestamps.
- Restore preview and restore run flow with local conflict handling.
- Backup, sync, and restore history screens.
- Foreground notifications and progress updates for long-running transfers.
- Android background scheduling and native folder watching foundation.
- Dark UI optimized for Android.

## Architecture

The app follows the existing feature-folder structure under `lib/features`.

- `models`: immutable data models and enums.
- `providers`: Riverpod state notifiers and screen-facing state.
- `presentation`: Flutter screens and widgets.
- `services`: platform bridges and focused integration helpers.
- `repositories`: local persistence and FTP/SFTP transfer implementations.
- `core`: shared theme, constants, widgets, and utility classes.

State management uses `flutter_riverpod`. Current repositories persist JSON
files under the app documents directory. SQLite is planned, but not yet used.

Android background work uses native Kotlin services and Flutter headless Dart
entrypoints:

- `scheduledSyncMain` runs due scheduled backup and sync work.
- `instantSyncMain` runs instant backup jobs and instant sync rules after file
  watcher events.

## Requirements

- Flutter SDK compatible with `sdk: >=3.8.0 <4.0.0`.
- Android Studio or Android command-line tools.
- Java 17 for the Android Gradle build.
- An Android device or emulator for runtime testing.

## Setup

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

The debug APK is generated at:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## Android Notes

The app declares network, storage, notification, foreground service, boot, and
Wi-Fi related permissions needed by the current feature set.

For best background behavior on physical devices:

- Allow notification permission.
- Allow storage access for selected folders.
- Disable battery optimization for OpenBackup when using scheduled or instant
  jobs.
- Keep FTP/SFTP credentials and paths correct before enabling background work.

Some Android vendors may still limit background services aggressively. The app
uses foreground `dataSync` services where required, but actual behavior can vary
by device policy.

The Android release `applicationId` is:

```text
com.openbackup.app
```

## Release Signing

Release builds do not use debug signing. Configure signing with either
`android/key.properties` or environment variables.

To use `android/key.properties`, copy `android/key.properties.example` to
`android/key.properties` and fill in the real keystore values:

```properties
storeFile=C:/path/to/openbackup-upload-keystore.jks
storePassword=your-store-password
keyAlias=openbackup
keyPassword=your-key-password
```

`android/key.properties` and keystore files are ignored by Git.

Environment variable alternatives:

```text
OPENBACKUP_UPLOAD_STORE_FILE
OPENBACKUP_UPLOAD_STORE_PASSWORD
OPENBACKUP_UPLOAD_KEY_ALIAS
OPENBACKUP_UPLOAD_KEY_PASSWORD
```

## Known Technical Debt

- Release signing requires local keystore values before building distributable
  release artifacts.
- SQLite persistence migration has started. FTP server records, backup jobs,
  and sync rules use SQLite; history and settings still use JSON-backed
  storage.
- Kotlin Gradle Plugin migration warning appears for some third-party plugins
  during debug builds. The current dependency set builds successfully, and the
  migration is deferred until compatible plugin versions are aligned.

## Development Workflow

Each logical change should pass:

```bash
flutter analyze
flutter test
flutter build apk --debug
```

Keep changes aligned with the existing Riverpod/provider/repository structure.
Avoid adding new packages or architecture unless a task clearly needs it.

## Project Status

See `PROJECT_STATUS.md` for the current feature inventory, build status, known
warnings, and recommended next work.
