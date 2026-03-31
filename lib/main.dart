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
import 'services/notification_service.dart';
import 'core/typography.dart';
import 'package:google_fonts/google_fonts.dart';

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

  // Initialize notifications and fire a smart reminder based on current state.
  // Only runs on mobile (Android/iOS) — local notifications need these platforms.
  if (Platform.isAndroid || Platform.isIOS) {
    await NotificationService.instance.initialize();
    // Query live due count — language pair defaults used here since providers
    // aren't ready yet. For a real user this fires after preferences load.
    try {
      final dueCount =
          await dbHelper.getDueCount('en', 'es'); // default pair
      final practicedToday =
          (await dbHelper.getWordsReviewedToday('en', 'es')) > 0;
      await NotificationService.instance.scheduleSmartReminder(
        dueCount: dueCount,
        practicedToday: practicedToday,
      );
    } catch (e) {
      debugPrint('[main] Smart reminder skipped: $e');
    }
  }

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
        useMaterial3: true,
        brightness: Brightness.dark, // Signature Dark Forest Mode
        primaryColor: SeedlingColors.seedlingGreen,
        scaffoldBackgroundColor: SeedlingColors.background,
        
        // Custom Color Scheme for specialized widgets
        colorScheme: ColorScheme.fromSeed(
          seedColor: SeedlingColors.seedlingGreen,
          brightness: Brightness.dark,
          primary: SeedlingColors.seedlingGreen,
          surface: SeedlingColors.cardBackground,
          error: SeedlingColors.error,
        ),

        // Global Typography Integration
        textTheme: GoogleFonts.outfitTextTheme().apply(
          bodyColor: SeedlingColors.textPrimary,
          displayColor: SeedlingColors.textPrimary,
        ),

        // Premium Nature Card Style
        cardTheme: CardThemeData(
          color: SeedlingColors.cardBackground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),

        // Immersive Modal styles
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: SeedlingColors.background,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: SeedlingColors.background,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
        ),

        // Immersive AppBar Style
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: SeedlingColors.textPrimary),
        ),

        // Organic Button Style
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: SeedlingColors.seedlingGreen,
            foregroundColor: SeedlingColors.background,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
            textStyle: SeedlingTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
