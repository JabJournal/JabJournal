# Peptide Tracker - Setup Guide

This is a cross-platform Flutter mobile app for tracking peptide usage, doses, and calculations. It features offline-first SQLite storage with encrypted backup/restore.

## Prerequisites

- Flutter 3.8.1 or later
- Dart 3.4.0 or later
- Xcode (iOS/macOS builds)
- Android Studio (Android builds)

## Install dependencies

```bash
flutter pub get
```

## Run the app

```bash
flutter run -d iphone    # iOS simulator or device
flutter run -d android   # Android emulator or device
flutter run -d macos     # macOS desktop
flutter run -d chrome    # Web (development)
flutter run -d windows   # Windows desktop
```

## Backups

JabJournal has no cloud account or server. All data is stored locally in SQLite and can be exported / imported as an encrypted JSON file via the in-app **Settings → Backup & Restore** menu. To restore on a new device, install the app, open Settings → Backup & Restore, and choose the `.jab_backup` file you exported.

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── config/                      # AppConfig
├── models/                      # Data models
├── providers/                   # State management (Provider)
├── screens/                     # UI screens
├── services/                    # Business logic services
└── utils/                       # Utilities and constants
```

## Key Features

- **Offline-First**: All data is stored locally in SQLite — no account, no server
- **Encrypted Backups**: Export and import an encrypted backup of all data
- **Scheduling**: Set recurring or one-time dose reminders with local notifications
- **Calculations**: Compute injection draw amounts from vial/syringe specs
- **Dashboard**: Stats, charts, and recent activity at a glance

## Development Notes

- The app uses Provider for state management
- SQLite for local persistence (offline-first)
- `flutter_local_notifications` for dose reminders
- Android uses `flutter_foreground_task` to keep scheduled notifications firing reliably on devices that aggressively kill backgrounded apps

## Troubleshooting

### Build issues
- Run `flutter clean` then `flutter pub get`
- Ensure you're on a compatible Flutter version

### Database issues
- Delete the app and reinstall to reset the database
- Check `lib/services/database/sqlite_service.dart` for the schema

## Next Steps

1. Customize the dashboard with additional widgets
2. Add schedule management UI improvements
3. Implement notification scheduling refinements
4. Add export/import functionality improvements
