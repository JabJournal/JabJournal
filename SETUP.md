# Peptide Tracker - Setup Guide

This is a cross-platform Flutter mobile app for tracking peptide usage, doses, and calculations. It features offline-first SQLite storage with optional Supabase sync for cloud backup.

## Prerequisites

- Flutter 3.8.1 or later
- Dart 3.4.0 or later
- iOS development environment (Xcode for Mac)
- Android development environment (Android Studio)

## Initial Setup

### 1. Install Dependencies

```bash
cd peptide_tracker
flutter pub get
```

### 2. Configure Supabase (Optional)

To enable cloud sync, update `lib/config/app_config.dart`:

```dart
class AppConfig {
  static const String supabaseUrl = 'YOUR_SUPABASE_PROJECT_URL';
  static const String supabasePublishableKey = 'YOUR_SUPABASE_PUBLISHABLE_KEY';
  // ... rest of config
}
```

**Getting Supabase credentials:**
1. Create a project at [supabase.com](https://supabase.com)
2. Go to Project Settings → API Keys
3. Copy the project URL and anon key
4. Paste into `app_config.dart`

### 3. Configure Firebase (Notifications)

For push notifications, you'll need to set up Firebase:

**Android:**
1. Download `google-services.json` from Firebase Console
2. Place in `android/app/`

**iOS:**
1. Download `GoogleService-Info.plist` from Firebase Console
2. Add to Xcode project under `ios/Runner/`

### 4. Create Supabase Database Schema

Run these SQL queries in Supabase SQL Editor to create tables:

```sql
CREATE TABLE peptides (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  sync_status TEXT DEFAULT 'pending',
  remote_id TEXT
);

CREATE TABLE doses (
  id TEXT PRIMARY KEY,
  peptide_id TEXT NOT NULL REFERENCES peptides(id),
  amount_mcg REAL NOT NULL,
  taken_at INTEGER NOT NULL,
  notes TEXT,
  sync_status TEXT DEFAULT 'pending',
  remote_id TEXT
);

CREATE TABLE peptide_schedules (
  id TEXT PRIMARY KEY,
  peptide_id TEXT NOT NULL REFERENCES peptides(id),
  frequency TEXT NOT NULL,
  days_of_week TEXT,
  time_of_day INTEGER NOT NULL,
  enabled INTEGER DEFAULT 1,
  sync_status TEXT DEFAULT 'pending',
  remote_id TEXT
);

CREATE TABLE calculations (
  id TEXT PRIMARY KEY,
  peptide_name TEXT NOT NULL,
  syringe_type TEXT NOT NULL,
  syringe_units INTEGER NOT NULL,
  vial_water_ml REAL NOT NULL,
  vial_peptide_ml REAL NOT NULL,
  desired_dose_mcg REAL NOT NULL,
  result_amount REAL NOT NULL,
  calculated_at INTEGER NOT NULL,
  sync_status TEXT DEFAULT 'pending',
  remote_id TEXT
);
```

## Running the App

### iOS
```bash
flutter run -d iphone
```

### Android
```bash
flutter run -d android
```

### Web (Development)
```bash
flutter run -d chrome
```

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── config/                      # Configuration files
├── models/                      # Data models
├── providers/                   # State management (Provider)
├── screens/                     # UI screens
├── services/                    # Business logic services
└── utils/                       # Utilities and constants
```

## Key Features

- **Offline-First**: All data stored locally in SQLite
- **Cloud Sync**: Optional Supabase integration for backup
- **Peptide Management**: Add, edit, delete peptides
- **Dose Tracking**: Log and view dose history
- **Calculator**: Calculate injection amounts based on vial/syringe specs
- **Notifications**: Schedule dose reminders (iOS/Android)
- **Dashboard**: View stats and summaries

## Development Notes

- The app uses Provider for state management
- SQLite for local persistence with offline-first architecture
- Supabase for optional cloud sync with conflict resolution
- Firebase Cloud Messaging for notifications

## Troubleshooting

### Supabase Connection Issues
- Verify URL and API key in `app_config.dart`
- Check network connectivity
- Look at console logs: `flutter logs`

### Database Issues
- Delete app and reinstall to reset database
- Check `lib/services/database/sqlite_service.dart` for schema

### Build Issues
- Run `flutter clean` then `flutter pub get`
- Ensure you're on a compatible Flutter version

## Next Steps

1. Configure Supabase for cloud sync
2. Set up Firebase for notifications
3. Customize the dashboard with additional widgets
4. Add schedule management UI
5. Implement notification scheduling
6. Add export/import functionality
