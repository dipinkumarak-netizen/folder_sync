# Real-Device Background and FTP Compatibility Test Plan

This checklist validates OpenBackup behavior on a physical Android device,
especially background backup/sync and Huawei modem FTP storage paths.

## Scope

- FTP and SFTP connection setup.
- Huawei modem FTP folder selection and manual remote path entry.
- Manual backup, instant backup, scheduled backup, and instant sync.
- Android permissions, notifications, boot restore, and battery optimization.
- SQLite migration from legacy JSON storage.

## Prerequisites

- A physical Android device with USB debugging enabled.
- The device and Huawei modem connected to the same network.
- Huawei modem FTP sharing enabled for the USB HDD.
- A known writable remote folder path on the modem USB HDD.
- Notification and storage permissions granted to OpenBackup.
- Battery optimization disabled for OpenBackup when testing background work.

## Build and Install

```bash
flutter build apk --debug
adb devices
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell monkey -p com.openbackup.app 1
```

Expected result:

- The app launches.
- First-run readiness appears only on fresh installs.
- No crash appears in `adb logcat`.

## Huawei Modem FTP Path Test

1. Add an FTP server using the modem host, port, username, and password.
2. Tap `Test Connection`.
3. Open the remote folder picker.
4. Try browsing from `/`.
5. If folders do not list, enter the known USB HDD path manually in `Remote Path`.
6. Tap `Open Path`.
7. If listing still fails but the path is known, tap `Select Folder`.
8. Save the FTP server.

Expected result:

- Connection test succeeds when credentials and network are correct.
- Manual remote path entry can save modem USB HDD paths even when listing is
  limited by the router FTP implementation.
- Backup and sync jobs can use the saved path.

Suggested Huawei paths to verify, depending on modem firmware:

```text
/
/USB
/USB1
/usb1
/storage
/mnt/usb
/HDD
```

## Manual Backup Test

1. Create a local test folder on the phone.
2. Add a small file such as `manual-1.txt`.
3. Create a backup job pointing to the Huawei FTP path.
4. Tap `Run Now`.
5. Add `manual-2.txt`.
6. Tap `Run Now` again.

Expected result:

- The first run uploads `manual-1.txt`.
- The second run uploads only `manual-2.txt`.
- The backup history records both runs.

## Instant Backup Test

1. Create a backup job with schedule `Instant Backup`.
2. Enable automatic scheduling in settings.
3. Disable battery optimization for OpenBackup.
4. Leave the app open and add `instant-foreground.txt` to the watched folder.
5. Move the app to background and add `instant-background.txt`.
6. Lock the screen and add `instant-locked.txt` through USB/MTP or another app.

Expected result:

- Foreground event uploads after the debounce delay.
- Background event uploads while the native foreground watcher is active.
- Locked-screen behavior may vary by Android vendor policy, but should work
  when the foreground watcher notification remains active.

## Instant Sync Test

1. Create a sync rule with trigger `Instant Sync`.
2. Use a non-destructive direction first, such as upload only.
3. Add a new local file.
4. Edit an existing local file.

Expected result:

- New files upload after the debounce delay.
- Modified files sync according to the selected conflict rule.
- Repeated runs do not transfer unchanged files.

## Scheduled Background Test

1. Create an hourly backup job or sync rule.
2. Enable automatic scheduling.
3. Confirm notification and battery settings are ready.
4. Reboot the device.
5. Wait for the scheduled interval or trigger the alarm manually during debug.

Useful commands:

```bash
adb shell dumpsys alarm | findstr openbackup
adb shell dumpsys deviceidle whitelist
adb logcat | findstr OpenBackup
```

Expected result:

- Boot receiver restores background scheduling.
- Scheduled headless work starts a foreground `dataSync` service.
- Jobs skip cleanly when Wi-Fi, home SSID, charging, or FTP requirements are
  not satisfied.

## SQLite Migration Test

1. Install a build that used JSON persistence and create FTP servers, jobs,
   sync rules, history, and settings.
2. Upgrade to the SQLite build using `adb install -r`.
3. Open each screen.

Expected result:

- Existing records are visible after upgrade.
- New edits persist after closing and reopening the app.
- No duplicate records are created after repeated launches.

## Log Collection

Use these commands while reproducing failures:

```bash
adb logcat -c
adb logcat > openbackup-device.log
adb shell dumpsys package com.openbackup.app > openbackup-package.txt
adb shell dumpsys activity services com.openbackup.app > openbackup-services.txt
adb shell dumpsys alarm > openbackup-alarms.txt
```

Attach the generated logs to the issue or test report.

## Pass Criteria

- `flutter analyze`, `flutter test`, and `flutter build apk --debug` pass.
- FTP path can be saved manually when Huawei folder listing is incomplete.
- Manual backup uploads only new files.
- Instant backup and instant sync trigger on real file events.
- Scheduled work survives app restart and device reboot where Android policy
  allows it.
- SQLite migration preserves existing user data.
