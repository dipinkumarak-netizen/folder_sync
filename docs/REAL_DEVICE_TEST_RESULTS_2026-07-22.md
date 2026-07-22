# Real-Device Test Results - 2026-07-22

Device:

- Model: `2201117PI`
- Product: `miel_p_in`
- ADB serial: `7DJZRWS4SKBY5DEA`

Build tested:

- Debug APK: `build/app/outputs/flutter-apk/app-debug.apk`
- Package: `com.openbackup.app`
- Version: `1.0.0`
- Version code: `1`

## Completed Checks

| Check | Result | Notes |
| --- | --- | --- |
| ADB device detection | Pass | Device appeared online after ADB server restart. |
| Debug APK install | Pass | `adb install -r` completed successfully. |
| App launch | Pass | `adb shell monkey -p com.openbackup.app 1` launched the app. |
| Package identity | Pass | Installed package is `com.openbackup.app`. |
| Foreground service permissions declared | Pass | `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_DATA_SYNC` are declared. |
| Boot receiver permission declared | Pass | `RECEIVE_BOOT_COMPLETED` is declared and granted. |
| Crash smoke check | Pass | Recent logcat did not show `FATAL EXCEPTION`, `AndroidRuntime`, or SQLite crash entries for the app. |

## Device State Observations

- App process was running after launch.
- `POST_NOTIFICATIONS` was not granted.
- `ACCESS_FINE_LOCATION` and `NEARBY_WIFI_DEVICES` were not granted.
- `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE`, and
  `MANAGE_EXTERNAL_STORAGE` were not granted.
- `pm grant com.openbackup.app android.permission.POST_NOTIFICATIONS` failed on
  this device because the shell user did not have runtime permission grant
  privileges.
- No active OpenBackup foreground services were listed at the time of the smoke
  check because no backup or sync jobs were configured.
- No OpenBackup alarms were listed at the time of the smoke check because no
  scheduled jobs or rules were configured.
- The app was not present in the device idle whitelist during the smoke check.

## Pending Manual Checks

These require user-side app configuration and Huawei modem credentials/paths:

- Grant notification permission from Android app settings.
- Grant folder/storage access through the app flow.
- Disable battery optimization for OpenBackup.
- Add the Huawei modem FTP server.
- Verify manual remote path selection for the USB HDD.
- Create and run a manual backup to the modem USB HDD path.
- Create an `Instant Backup` job and verify foreground/background events.
- Create an `Instant Sync` rule and verify foreground/background events.
- Create an hourly scheduled job or rule and verify alarm registration.
- Reboot the device and verify scheduled/instant watcher restoration.

## Next Test Commands

Run these after permissions and jobs are configured:

```bash
adb shell dumpsys activity services com.openbackup.app
adb shell dumpsys alarm | findstr com.openbackup.app
adb logcat -c
adb logcat > openbackup-real-device.log
```

Use `docs/REAL_DEVICE_BACKGROUND_AND_FTP_TEST_PLAN.md` for the full test flow.
