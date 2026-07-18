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

## Synchronization Module

- Sync Rule List Screen
- Sync Rule Form Screen
- Direction Rules
- Conflict Rules
- Delete Rules
- File Filter Rules
- Wi-Fi Only and Home Wi-Fi Rules
- Local Sync Rule Persistence

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

- Manual Sync Runner
- Remote File Diffing
- Foreground Sync Progress

Milestone 5

Scheduler

Milestone 6

Restore

Milestone 7

History

Milestone 8

Settings

Milestone 9

GitHub Open Source Release

---

Last Updated

2026-07-18
