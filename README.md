# JabJournal

An offline-first app for tracking peptide doses, injection calculations, and schedules. Currently available on Android, with iOS support coming soon.

> [!IMPORTANT]  
> This app was created with the help of Claude Code. If you do not like that, please refrain from using the app.

> [!WARNING]  
> Please note that the app is not intended for clinical use, and any medical advice should be obtained from a qualified healthcare provider.

## Features

- **Peptide Management** — add, edit, and delete peptides with vendor and dosage info
- **Dose Logging** — record doses with injection site, side effects, and ISR severity
- **Injection Calculator** — compute draw amounts from vial/syringe specs and desired dose
- **Schedules** — set recurring or one-time dose reminders (daily, weekly, specific dates)
- **Weight Tracking** — log weight entries, optionally linked to a dose
- **Dashboard** — summary stats and charts across all tracked data
- **Offline-First** — all data stored locally in SQLite; works with no internet connection
- **Cloud Sync** — optional Supabase integration for backup and multi-device access
- **Local Notifications** — timezone-aware dose reminders with a foreground service on Android

## Getting Started

### Prerequisites

- Flutter 3.8.1+ / Dart 3.4.0+
- Xcode (iOS/macOS builds)
- Android Studio (Android builds)

### Install dependencies

```bash
flutter pub get
```

### Run the app

```bash
flutter run -d iphone    # iOS simulator or device
flutter run -d android   # Android emulator or device
flutter run -d macos     # macOS desktop
flutter run -d chrome    # Web (development)
flutter run -d windows   # Windows desktop
```

### Other commands

```bash
flutter analyze          # Lint (Dart analyzer + flutter_lints)
flutter test             # Run all tests
flutter build apk        # Build Android APK
flutter clean            # Clear build artifacts
```

## Cloud Sync Setup (Optional)

By default the app runs fully offline. To enable Supabase sync, update `lib/config/app_config.dart`:

```dart
class AppConfig {
  static const String supabaseUrl = 'YOUR_SUPABASE_PROJECT_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
}
```

See [SETUP.md](SETUP.md) for the full SQL schema to create the required Supabase tables.

## Architecture

```
Screens (lib/screens/)
    ↓
Providers (lib/providers/)   — ChangeNotifier, consumed via Provider / context.watch
    ↓
Services (lib/services/)     — business logic and I/O
    ↓
Models (lib/models/)         — toMap/fromMap + toJson/fromJson
```

State management uses 11 `ChangeNotifier` providers wired in `main.dart` via `MultiProvider`. The local database is SQLite (via `sqflite`), currently at schema version 3. Every row carries a `sync_status` column (`pending` | `synced` | `failed`) and a `remote_id` for Supabase sync.

### Project Structure

```
lib/
├── main.dart
├── config/          # AppConfig (Supabase credentials, sync interval)
├── models/          # Peptide, DoseHistory, PeptideSchedule, PeptideCalculation, WeightEntry
├── providers/       # Domain providers (peptides, doses, schedules, calculator, weight, …)
├── screens/
│   ├── home/        # Shell with 5-tab bottom nav
│   ├── peptides/
│   ├── doses/
│   ├── calculator/
│   ├── schedules/
│   ├── weight/
│   └── settings/
├── services/
│   ├── database/    # SQLiteService (singleton + migrations), DatabaseHelper (CRUD)
│   ├── supabase/    # SupabaseService, SyncManager
│   ├── notification_service.dart
│   ├── foreground_service.dart
│   └── notification_router.dart
└── utils/
```

## Troubleshooting

| Problem                             | Fix                                                                                                                         |
| ----------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| Supabase not syncing                | Verify URL and anon key in `app_config.dart`; check `flutter logs`                                                          |
| Database corruption                 | Delete and reinstall to reset SQLite; see `sqlite_service.dart` for schema                                                  |
| Build failures                      | `flutter clean && flutter pub get`                                                                                          |
| Notifications not firing on Android | Ensure battery optimization is disabled for the app; the foreground service handles this automatically on supported devices |
