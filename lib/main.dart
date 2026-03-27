import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database/database_helper.dart';
import 'screens/splash.dart';
import 'core/colors.dart';
import 'core/supabase_config.dart';
import 'services/auth_service.dart';
import 'services/sync_manager.dart';
import 'services/subscription_service.dart';
import 'services/audio_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  
  // Initialize Services
  await AuthService().initialize();
  await SyncManager().initialize();
  await SubscriptionService().initialize();
  
  // Initialize database
  final dbHelper = DatabaseHelper();
  await dbHelper.database;
  
  // Initialize SFX — warm up all audio channels before the first quiz.
  await AudioService.instance.initialize();
  
  runApp(
    const ProviderScope(
      child: SeedlingApp(),
    ),
  );
}

class SeedlingApp extends StatelessWidget {
  const SeedlingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Seedling',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: SeedlingColors.seedlingGreen,
        scaffoldBackgroundColor: SeedlingColors.background,
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
