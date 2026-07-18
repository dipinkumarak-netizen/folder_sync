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
- Splash Screen

## FTP Module

- FTP Server List Screen
- FTP Server Model
- FTP Memory Repository
- FTP Provider
- FTP Connection Testing
- Local FTP Server Persistence

## Backup Module

- Backup Job List Screen
- Backup Job Form Screen
- Local Folder Picker
- Manual New-Files-Only FTP Backup
- Backup Run Status Summary
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
- Wi-Fi Only and Home Wi-Fi Rules
- Local Sync Rule Persistence
- Manual Sync Runner
- Sync History Logging
- Wi-Fi Only Sync Enforcement
- Home Wi-Fi Name Check Foundation
- Protected Delete Preview Screen
- Confirmed Delete Rule Execution
- Foreground Sync Progress

## Restore Module

- Restore Screen
- FTP Restore Preview
- Manual FTP Restore Runner
- Existing Local File Skip Protection
- Restore Conflict Rules
- Restore Local Conflict Preview
- Restore Filters
- Restore Progress Details
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
- Automatic Scheduling Toggle
- Backup and Sync Wi-Fi Defaults
- Foreground Notification Toggle
- Permission Shortcuts
- Clear History Action

## History Module

- History Entry Model
- Local History Persistence
- History Screen
- Backup Run History Logging
- History Filters
- Clear History Action

---

# Current Version

v0.1.0

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
- Restore History Logging

Milestone 7

History

- Backup History
- Sync History Foundation
- Restore History Foundation

Pending:

- Restore History Logging

Milestone 8

Settings

- Settings Screen
- Scheduling Settings
- Network Defaults
- Permission Shortcuts
- Local Data Actions

Milestone 9

GitHub Open Source Release

---

Last Updated

2026-07-18
