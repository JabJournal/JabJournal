# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

11 `ChangeNotifier` providers wired in `main.dart` via `MultiProvider`. Each provider owns one domain (peptides, dose history, schedules, calculator, weight, sync, notifications, theme, backup). Providers call services directly; there is no intermediate repository abstraction above the service layer.

### Data Layer

- **SQLiteService** (`lib/services/database/sqlite_service.dart`) — singleton holding the database instance, schema creation, and migrations.
- **DatabaseHelper** (`lib/services/database/database_helper.dart`) — all CRUD methods, called by providers.
- Database is at version 3; migrations live in `SQLiteService._migrateToV2` / `_migrateToV3`.
- Every row has a `sync_status` column (`'pending'` | `'synced'` | `'failed'`) and `remote_id` for Supabase sync.

### Sync

- **SyncManager** (`lib/services/supabase/sync_manager.dart`) — monitors connectivity (connectivity_plus) and flushes pending rows to Supabase on reconnect. Sync interval is 300 s (configurable in `lib/config/app_config.dart`).
- **SupabaseService** (`lib/services/supabase/supabase_service.dart`) — thin wrapper around the Supabase REST client.
- Supabase credentials are placeholders in `app_config.dart`; the app works fully offline without them.

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
