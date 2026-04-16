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
import 'services/vocabulary_service.dart';
import 'services/settings_service.dart';
import 'services/tts_service.dart';
import 'services/iap_service.dart';
import 'core/typography.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Initialize Environment
  await dotenv.load(fileName: ".env");

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
    debug: true,
  );

  // Initialize Services
  await AuthService().initialize();
  await SyncManager().initialize();
  await SubscriptionService().initialize();
  await SettingsService().initialize();

  // Initialize database
  final dbHelper = DatabaseHelper();
  await dbHelper.database;

  // Normalize categories (converts display names to IDs for existing data)
  await VocabularyService.normalizeDatabaseCategories();

  // Initialize SFX — warm up all audio channels before the first quiz.
  await AudioService.instance.initialize();

  // Initialize notifications and fire a smart reminder based on current state.
  // Only runs on mobile (Android/iOS) — local notifications need these platforms.
  if (Platform.isAndroid || Platform.isIOS) {
    await NotificationService.instance.initialize();
    IapService.instance.initialize();
    IapService.instance.loadProducts(); // Prefetch products for snappy UI
    
    // Query live due count — language pair defaults used here since providers
    // aren't ready yet. For a real user this fires after preferences load.
    try {
      final dueCount = await dbHelper.getDueCount('en', 'es'); // default pair
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

  // Ready to switch to the Flutter splash/home!
  FlutterNativeSplash.remove();

  runApp(const ProviderScope(child: SeedlingApp()));
}

class SeedlingApp extends StatelessWidget {
  const SeedlingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Seedling',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            if (child != null) child,
            const _GlobalTtsOverlay(),
          ],
        );
      },
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

        // Global background — prevents any Scaffold from showing white
        // scaffoldBackgroundColor was already specified above.

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
            textStyle: SeedlingTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class _GlobalTtsOverlay extends StatelessWidget {
  const _GlobalTtsOverlay();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double?>(
      valueListenable: TtsService.instance.downloadProgress,
      builder: (context, progress, child) {
        if (progress == null) return const SizedBox.shrink();
        
        return Positioned(
          bottom: 40,
          left: 20,
          right: 20,
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              builder: (context, val, child) {
                return Opacity(
                  opacity: val,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - val)),
                    child: child,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: SeedlingColors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: SeedlingColors.seedlingGreen.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: SeedlingColors.seedlingGreen,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Downloading Voice Model',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.white.withValues(alpha: 0.1),
                              valueColor: const AlwaysStoppedAnimation<Color>(SeedlingColors.seedlingGreen),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: SeedlingColors.seedlingGreen,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
