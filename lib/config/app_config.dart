class AppConfig {
  // Supabase Configuration
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabasePublishableKey = 'YOUR_SUPABASE_PUBLISHABLE_KEY';

  // Firebase Configuration
  static const String firebaseProjectId = 'YOUR_FIREBASE_PROJECT_ID';

  // Database Configuration
  static const String databaseName = 'jab_journal.db';
  static const int databaseVersion = 7;

  // App Configuration
  static const String appName = 'JabJournal';
  static const String appVersion = '1.0.0';

  // Sync Configuration
  static const int syncIntervalSeconds = 300;
  static const int maxRetries = 3;
}
