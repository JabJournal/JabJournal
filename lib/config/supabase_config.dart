import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_config.dart';

class SupabaseConfig {
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }

  static SupabaseClient getClient() {
    return Supabase.instance.client;
  }

  static Future<void> createTablesIfNotExist() async {
    final client = getClient();

    try {
      await client.rpc('create_tables_if_not_exist');
    } catch (e) {
      debugPrint('Tables may already exist or error creating tables: $e');
    }
  }
}
