import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ================ SUPABASE CLIENT CONFIGURATION ================

class SupabaseConfig {
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ??
      'https://ikhvhivwqsbgiknhvxbq.supabase.co'; // Fallback for safety

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ??
      ''; // Value should be in .env

  static SupabaseClient get client => Supabase.instance.client;
}
