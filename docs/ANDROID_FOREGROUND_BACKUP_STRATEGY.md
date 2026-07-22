# Android Foreground Backup Strategy

## Goal

OpenBackup backs up user-selected local folders to FTP. Long-running backup work
must remain visible to the user and must comply with modern Android foreground
service requirements.

## Current Foundation

- FTP backup work uses the `dataSync` foreground service type.
- The Android manifest declares foreground service permissions required for
  data sync work.
- The Android manifest declares `POST_NOTIFICATIONS` for Android 13 and newer.
- A native `BackupForegroundService` creates the notification channel and starts
  as a `dataSync` foreground service.
- The Backup Jobs screen checks notification permission readiness and lets the
  user request the permission or open app settings.
- The Dart backup runner starts the native foreground service before backup work
  begins and stops it after success or failure.
- Scheduled backup jobs run through a native Android alarm receiver and a
  headless Dart entrypoint.
- Instant backup jobs reuse the native folder watcher service. File events
  debounce into the headless Dart instant work entrypoint.

## Permission Strategy

- Use `POST_NOTIFICATIONS` for foreground backup progress visibility on Android
  13 and newer.
- Use selected-folder access through the existing folder picker flow.
- Do not request all-files access by default. `MANAGE_EXTERNAL_STORAGE` is a
  high-risk permission and should only be considered if the app later needs
  broad device-wide backup outside user-selected folders.
- Keep FTP/network permissions in the manifest because backup uploads require
  network access.

## Foreground Service Strategy

- User-triggered manual backup can run after the user starts it from the app.
- Scheduled backup can run from Android background alarms.
- Instant backup can run from native folder watcher events when automatic
  scheduling is enabled.
- The service must always show an ongoing notification while backup work is
  active.
- Android 14 and newer require a foreground service type and matching permission;
  this project uses `dataSync` for backup upload work.

## Remaining Work

- Replace the debug release signing configuration before distribution.
- Review manufacturer-specific background restrictions on physical devices.
- Keep the Kotlin Gradle Plugin migration warning tracked until plugin versions
  support Flutter built-in Kotlin cleanly.
