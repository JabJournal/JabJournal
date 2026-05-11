class AppConstants {
  static const String appName = 'JabJournal';
  static const String appVersion = '1.0.0';

  static const Map<String, List<int>> syringeConfigurations = {
    'U-100': [100, 50, 30],
    'U-40': [80, 40, 20, 12],
  };

  static const List<String> frequencies = ['daily', 'weekly', 'custom'];

  static const int dbVersion = 1;
  static const String dbName = 'jab_journal.db';
}
