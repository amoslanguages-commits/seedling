import 'package:supabase_flutter/supabase_flutter.dart';

// ================ SUPABASE CLIENT CONFIGURATION ================

class SupabaseConfig {
  static const String supabaseUrl = 'https://ikhvhivwqsbgiknhvxbq.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlraHZoaXZ3cXNiZ2lrbmh2eGJxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQwNzQ3NjksImV4cCI6MjA4OTY1MDc2OX0.e_aHX3Gg9eijznm_2qbNfUxf63_YYDyvGuYsfPUHwD0';

  static SupabaseClient get client => Supabase.instance.client;
}
