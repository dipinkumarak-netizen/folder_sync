# OpenBackup Project Status

Version : 1.0.0

---

# Project Vision

OpenBackup is an open source Android backup and synchronization application
built with Flutter.

Primary target:

- Local Storage → FTP Backup
- FTP Synchronization
- Scheduled Backup
- Restore
- Backup History
- Completely Offline
- AMOLED Dark Theme

---

# Technology Stack

Flutter

Riverpod

SQLite (planned)

FTPConnect

Permission Handler

Logger

File Picker

---

# Completed

## Foundation

- Project Created
- Dark Theme
- Navigation
- Dashboard
- Dashboard Readiness Status
- Dashboard Wi-Fi SSID Status
- Splash Screen

## FTP Module

- FTP Server List Screen
- FTP Server Model
- FTP Memory Repository
- FTP Provider
- FTP Connection Testing
- FTP Connection Failure Details
- Remote Folder Picker
- Local FTP Server Persistence

## Backup Module

- Backup Job List Screen
- Backup Job Form Screen
- Local Folder Picker
- Remote Folder Picker
- Manual New-Files-Only FTP Backup
- Backup Run Status Summary
- Live Backup Transfer Status Bar
- Backup Transfer Speed Display
- Backup Notification Progress Details
- Local Backup Job Persistence
- Android Foreground Backup Permission Foundation
- Android Data Sync Foreground Service Skeleton
- Dart Backup Runner Foreground Service Handoff
- Scheduled Backup Jobs
- Backup Wi-Fi Schedule Rules

## Synchronization Module

- Sync Rule List Screen
- Sync Rule Form Screen
- Direction Rules
- Conflict Rules
- Delete Rules
- File Filter Rules
- Remote Folder Picker
- Wi-Fi Only and Home Wi-Fi Rules
- Local Sync Rule Persistence
- Manual Sync Runner
- Sync History Logging
- Wi-Fi Only Sync Enforcement
- Home Wi-Fi Name Check Foundation
- Protected Delete Preview Screen
- Confirmed Delete Rule Execution
- Foreground Sync Progress
- Live Sync Transfer Status Bar
- Sync Transfer Speed Display
- Sync Notification Progress Details

## Restore Module

- Restore Screen
- FTP Restore Preview
- Remote Folder Picker
- Manual FTP Restore Runner
- Existing Local File Skip Protection
- Restore Conflict Rules
- Restore Local Conflict Preview
- Restore Filters
- Restore Progress Details
- Restore Transfer Speed Display
- Restore Notification Progress Details
- Restore Cancellation Support
- Foreground Restore Progress
- Restore History Logging

## Scheduler Module

- In-App Sync Scheduler Foundation
- Android Background Schedule Foundation
- Headless Dart Scheduled Runner
- Scheduled Backup Jobs
- Hourly Sync Rule Trigger
- Daily Sync Rule Trigger
- Home Wi-Fi Sync Rule Trigger Foundation

## Settings Module

- Settings Screen
- Persistent App Settings
- First-Run Readiness Flow
- Automatic Scheduling Toggle
- Backup and Sync Wi-Fi Defaults
- Foreground Notification Toggle
- Permission Shortcuts
- Storage and Permission Readiness Screen
- Android Readiness Checklist
- Native Battery Optimization Request
- Clear History Action

## History Module

- History Entry Model
- Local History Persistence
- History Screen
- History Detail Screen
- Per-Run File Report Foundation
- Backup Run History Logging
- Failure Reason Clarity
- History Filters
- Clear History Action

---

# Current Version

v0.1.0

---

# Current Technical Inventory

Last Reviewed: 2026-07-22

## Build and Test Status

- `flutter analyze` passes.
- `flutter test` passes.
- `flutter build apk --debug` passes.
- Android debug build still prints a Kotlin Gradle Plugin migration warning for
  `battery_plus`, `device_info_plus`, and `file_picker`.

## Kotlin Gradle Plugin Warning

Status: Deferred

The warning was investigated on 2026-07-22.

Stable major upgrades are not currently safe as a single production change:

- `device_info_plus 13.x` conflicts with stable `file_picker 11.x` through
  incompatible `win32` constraints.
- `battery_plus 7.x` and `file_picker 11.x` require newer Android built-in
  Kotlin migration behavior, but the current Flutter Gradle plugin path still
  requires `android.newDsl=false`.
- Enabling `android.builtInKotlin=true` with the current setup breaks the debug
  APK build.

Next action:

- Keep the current dependency set until Flutter/plugin compatibility is aligned.
- Revisit this as a dedicated dependency migration task, preferably after
  confirming a compatible stable `file_picker` release or a Flutter Gradle
  plugin update that supports the new DSL path cleanly.

## Remaining Feature Inventory

- SQLite persistence is still planned; current repositories are memory/local
  file based.
- Remote file diffing is still pending for synchronization.
- Background folder watching is still pending for backup.
- Release application ID and signing configuration are still TODOs in Android
  Gradle configuration.
- README still contains default Flutter starter documentation and should be
  replaced with OpenBackup-specific setup, feature, and contribution details.

## Recommended Next Task

Priority: README and project documentation refresh.

Reason:

- The build is currently green, but public project documentation is stale.
- This is low-risk and will make future development, testing, and release work
  clearer before larger persistence or scheduler changes.

---

# Current File Number

File 21

---

# Next File

lib/features/ftp/presentation/ftp_server_form_screen.dart

Status:

Not Started

---

# Coding Rules

One Reply = One File

Full Replace

Production Ready Code Only

No Placeholder Code

Version Header Required

Documentation Required

---

# Upcoming Milestones

Milestone 2

Working FTP

- Add Server
- Edit Server
- Delete Server
- Test Connection

Milestone 3

Working Backup

- Select Local Folder
- Select FTP Server
- Manual Backup
- New Files Only Tracking
- Backup Job Status

Pending:

- Foreground Backup Progress Notifications
- Scheduled Backup
- Background Folder Watching

Milestone 4

Synchronization

- Rule Management
- Upload / Download / Two-Way / Mirror Modes
- Conflict Handling Rules
- Delete Handling Rules
- Wi-Fi Only Rules

Pending:

- Remote File Diffing

Milestone 5

Scheduler

- In-App Sync Scheduler Foundation
- Android AlarmManager Schedule Registration
- Headless Dart Scheduled Runner
- Scheduled Backup Jobs
- Sync Rule Trigger Evaluation

Completed:

- Restore Module Foundation

Milestone 6

Restore

- FTP Restore Preview
- Manual FTP Restore Runner
- Skip / Overwrite / Keep Both Conflict Rules
- Local Conflict Count Preview
- Subfolder / Hidden / Pattern / Size Restore Filters
- Restore Progress UI and Foreground Updates
- Restore Cancellation UI and History
- Restore History Logging

Milestone 7

History

- Backup History
- Sync History Foundation
- Restore History Foundation
- History Detail Screen
- Per-Run File Report Foundation

Milestone 8

Settings

- Settings Screen
- Scheduling Settings
- Network Defaults
- Permission Shortcuts
- Storage and Permission Readiness Screen
- Local Data Actions

Milestone 9

GitHub Open Source Release

---

Last Updated

2026-07-18
