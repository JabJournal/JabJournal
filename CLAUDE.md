# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Git Workflow

This repo is hosted on a public GitHub org. Never commit directly to `main`.

**Branch naming:**
- `feature/short-description` — new user-facing functionality
- `dev/short-description` — work-in-progress, experiments, or non-feature changes

Always create a PR to merge into `main`. Keep commits deliberate and scoped — one logical change per PR.

## Commands

```bash
flutter pub get          # Install dependencies
flutter analyze          # Lint (Dart analyzer + flutter_lints)
flutter test             # Run all tests
flutter test test/widget_test.dart  # Run a single test file
flutter run -d macos     # Run on macOS (also: iphone, android, chrome, windows)
flutter build apk        # Build Android APK
flutter clean            # Clear build artifacts
```

## Architecture

**JabJournal** is an offline-first Flutter app for tracking peptide doses, injection calculations, and schedules. It targets iOS, Android, macOS, Windows, Web, and Linux.

### Layered Structure

```
Screens (lib/screens/)
    ↓
Providers (lib/providers/) — ChangeNotifier, consumed via Provider.of / context.watch
    ↓
Services (lib/services/) — business logic and I/O
    ↓
Models (lib/models/) — toMap/fromMap + toJson/fromJson on every model
```

### State Management

10 `ChangeNotifier` providers wired in `main.dart` via `MultiProvider`. Each provider owns one domain (peptides, dose history, schedules, calculator, weight, notifications, theme, backup, foreground service, notification status). Providers call services directly; there is no intermediate repository abstraction above the service layer.

### Data Layer

- **SQLiteService** (`lib/services/database/sqlite_service.dart`) — singleton holding the database instance, schema creation, and migrations.
- **DatabaseHelper** (`lib/services/database/database_helper.dart`) — all CRUD methods, called by providers.
- Database is at version 7; migrations live in `SQLiteService._migrateToV2` through `_migrateToV7`.
- Every row has a `sync_status` column (always `'pending'`) and `remote_id` (always `null`) for legacy reasons — Supabase cloud sync was removed in 0.2.0. These columns can be ignored for new development.

### Cloud Sync

Removed in 0.2.0. The previous `SyncManager` and `SupabaseService` were untested and not in use. If cloud sync is needed again, it would need to be re-added from scratch against a new backend.

### Notifications

- **NotificationService** (`lib/services/notification_service.dart`) — schedules and shows local notifications via `flutter_local_notifications`; timezone-aware via `flutter_timezone`.
- **ForegroundService** (`lib/services/foreground_service.dart`) — Android foreground service that keeps notifications alive on battery-aggressive devices.
- **NotificationRouter** (`lib/services/notification_router.dart`) — routes tapped notifications to the appropriate screen.

### Key Models

| Model | File | Notable fields |
|---|---|---|
| `Peptide` | `lib/models/peptide.dart` | name, vendor, dosageStrength |
| `DoseHistory` | `lib/models/dose_history.dart` | amountMcg, injectionSite, sideEffects (JSON list), IsrSeverity enum |
| `PeptideSchedule` | `lib/models/schedule.dart` | frequency (once/weekly), daysOfWeek (JSON list), specificDate, endDate |
| `PeptideCalculation` | `lib/models/peptide_calculation.dart` | syringeType, vial specs, desiredDoseMcg, resultAmount |
| `WeightEntry` | `lib/models/weight_entry.dart` | weightLbs, optional doseId foreign key |

### Navigation

`HomeScreen` (`lib/screens/home/home_screen.dart`) is the shell with 5 bottom-nav tabs: Dashboard, Peptides, Log Dose, Calculator, and Schedules. Settings and Backup are pushed from the Settings tab.
