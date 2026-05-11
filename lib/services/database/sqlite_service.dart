import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../config/app_config.dart';

class SQLiteService {
  static final SQLiteService _instance = SQLiteService._internal();
  static Database? _database;

  SQLiteService._internal();

  factory SQLiteService() {
    return _instance;
  }

  Future<Database> get database async {
    _database ??= await _initializeDatabase();
    return _database!;
  }

  Future<Database> _initializeDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, AppConfig.databaseName);

    return openDatabase(
      path,
      version: AppConfig.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v1 → v2: add tracking columns + weight_entries table
    if (oldVersion < 2) {
      await _migrateToV2(db);
    }
    // v2 → v3: schedule frequency + once/end-date support
    if (oldVersion < 3) {
      await _migrateToV3(db);
    }
    // v3 → v4: user-chosen color per peptide
    if (oldVersion < 4) {
      await _migrateToV4(db);
    }
    // v4 → v5: user-chosen icon per peptide
    if (oldVersion < 5) {
      await _migrateToV5(db);
    }
    // Always make sure the latest schema exists (idempotent CREATE IF NOT EXISTS).
    await _createTables(db);
  }

  Future<void> _migrateToV2(Database db) async {
    // Helper: add a column only if it doesn't already exist.
    Future<void> addCol(String table, String col, String def) async {
      final cols = await db.rawQuery('PRAGMA table_info($table)');
      final exists = cols.any((c) => c['name'] == col);
      if (!exists) {
        await db.execute('ALTER TABLE $table ADD COLUMN $col $def');
      }
    }

    await addCol('peptides', 'vendor', 'TEXT');
    await addCol('peptides', 'dosage_strength', 'TEXT');

    await addCol('doses', 'injection_site', 'TEXT');
    await addCol('doses', 'side_effects', 'TEXT');
    await addCol('doses', 'injection_site_reaction', 'TEXT');
    await addCol('doses', 'isr_severity', 'TEXT');
  }

  Future<void> _migrateToV3(Database db) async {
    Future<void> addCol(String table, String col, String def) async {
      final cols = await db.rawQuery('PRAGMA table_info($table)');
      final exists = cols.any((c) => c['name'] == col);
      if (!exists) {
        await db.execute('ALTER TABLE $table ADD COLUMN $col $def');
      }
    }

    // Once-vs-weekly + optional end date.
    await addCol('peptide_schedules', 'specific_date', 'INTEGER');
    await addCol('peptide_schedules', 'end_date', 'INTEGER');

    // Migrate legacy 'custom' frequency to 'weekly' since they meant the same thing.
    await db.execute(
        "UPDATE peptide_schedules SET frequency = 'weekly' WHERE frequency = 'custom'");
  }

  Future<void> _migrateToV4(Database db) async {
    final cols = await db.rawQuery('PRAGMA table_info(peptides)');
    if (!cols.any((c) => c['name'] == 'color_hex')) {
      await db.execute('ALTER TABLE peptides ADD COLUMN color_hex TEXT');
    }
  }

  Future<void> _migrateToV5(Database db) async {
    final cols = await db.rawQuery('PRAGMA table_info(peptides)');
    if (!cols.any((c) => c['name'] == 'icon_name')) {
      await db.execute('ALTER TABLE peptides ADD COLUMN icon_name TEXT');
    }
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS peptides (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        vendor TEXT,
        dosage_strength TEXT,
        color_hex TEXT,
        icon_name TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sync_status TEXT DEFAULT 'pending',
        remote_id TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS doses (
        id TEXT PRIMARY KEY,
        peptide_id TEXT NOT NULL,
        amount_mcg REAL NOT NULL,
        taken_at INTEGER NOT NULL,
        notes TEXT,
        injection_site TEXT,
        side_effects TEXT,
        injection_site_reaction TEXT,
        isr_severity TEXT,
        sync_status TEXT DEFAULT 'pending',
        remote_id TEXT,
        FOREIGN KEY (peptide_id) REFERENCES peptides (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS peptide_schedules (
        id TEXT PRIMARY KEY,
        peptide_id TEXT NOT NULL,
        frequency TEXT NOT NULL,
        days_of_week TEXT,
        time_of_day INTEGER NOT NULL,
        enabled INTEGER DEFAULT 1,
        specific_date INTEGER,
        end_date INTEGER,
        sync_status TEXT DEFAULT 'pending',
        remote_id TEXT,
        FOREIGN KEY (peptide_id) REFERENCES peptides (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS calculations (
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
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS weight_entries (
        id TEXT PRIMARY KEY,
        weight_lbs REAL NOT NULL,
        recorded_at INTEGER NOT NULL,
        notes TEXT,
        dose_id TEXT,
        sync_status TEXT DEFAULT 'pending',
        remote_id TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_doses_peptide_id ON doses(peptide_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_schedules_peptide_id ON peptide_schedules(peptide_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_doses_taken_at ON doses(taken_at)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_weights_recorded_at ON weight_entries(recorded_at)
    ''');
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
