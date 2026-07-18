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
- Scheduled/background backup should start the native foreground service before
  long-running upload work begins.
- The service must always show an ongoing notification while backup work is
  active.
- Android 14 and newer require a foreground service type and matching permission;
  this project uses `dataSync` for backup upload work.

## Next Implementation Step

Wire the Dart backup runner to the native foreground service lifecycle:

1. Start `BackupForegroundService` before running a manual backup.
2. Update the foreground notification with progress.
3. Stop the service when the backup completes or fails.
4. Add a scheduler only after persistence and foreground service lifecycle are
   stable.
