import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_helper.dart';
import '../models/word.dart';
import '../services/subscription_service.dart';
import '../services/usage_service.dart';
import 'course_provider.dart';
import '../models/gamification.dart';
import '../services/settings_service.dart';
import '../services/sync_manager.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/foundation.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../services/podcast_service.dart';
import '../core/supabase_config.dart';

final settingsService = SettingsService();

class SettingsState {
  final bool notificationsEnabled;
  final bool soundEffectsEnabled;
  final bool hapticsEnabled;
  final int dailyWordGoal;
  final bool cloudSyncEnabled;
  final TimeOfDay reminderTime;
  final String nativeLanguageCode;
  final String selectedAmbientTrack;
  final String selectedBrainwaveType;

  SettingsState({
    required this.notificationsEnabled,
    required this.soundEffectsEnabled,
    required this.hapticsEnabled,
    required this.dailyWordGoal,
    required this.cloudSyncEnabled,
    required this.reminderTime,
    required this.nativeLanguageCode,
    required this.selectedAmbientTrack,
    required this.selectedBrainwaveType,
  });

  factory SettingsState.initial() => SettingsState(
    notificationsEnabled: settingsService.notificationsEnabled,
    soundEffectsEnabled: settingsService.soundEffectsEnabled,
    hapticsEnabled: settingsService.hapticsEnabled,
    dailyWordGoal: settingsService.dailyWordGoal,
    cloudSyncEnabled: settingsService.cloudSyncEnabled,
    reminderTime: settingsService.reminderTime,
    nativeLanguageCode: settingsService.nativeLanguageCode,
    selectedAmbientTrack: settingsService.selectedAmbientTrack,
    selectedBrainwaveType: settingsService.selectedBrainwaveType,
  );

  SettingsState copyWith({
    bool? notificationsEnabled,
    bool? soundEffectsEnabled,
    bool? hapticsEnabled,
    int? dailyWordGoal,
    bool? cloudSyncEnabled,
    TimeOfDay? reminderTime,
    String? nativeLanguageCode,
    String? selectedAmbientTrack,
    String? selectedBrainwaveType,
  }) => SettingsState(
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    soundEffectsEnabled: soundEffectsEnabled ?? this.soundEffectsEnabled,
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    dailyWordGoal: dailyWordGoal ?? this.dailyWordGoal,
    cloudSyncEnabled: cloudSyncEnabled ?? this.cloudSyncEnabled,
    reminderTime: reminderTime ?? this.reminderTime,
    nativeLanguageCode: nativeLanguageCode ?? this.nativeLanguageCode,
    selectedAmbientTrack: selectedAmbientTrack ?? this.selectedAmbientTrack,
    selectedBrainwaveType: selectedBrainwaveType ?? this.selectedBrainwaveType,
  );
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    return SettingsNotifier();
  },
);

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(SettingsState.initial()) {
    settingsService.addListener(_onServiceSettingsChanged);
  }

  void _onServiceSettingsChanged() {
    state = SettingsState.initial();
  }

  @override
  void dispose() {
    settingsService.removeListener(_onServiceSettingsChanged);
    super.dispose();
  }

  Future<void> toggleNotifications(bool value) async {
    await settingsService.setNotificationsEnabled(value);
    if (value) {
      await NotificationService.instance.scheduleDailyReminder(
        hour: state.reminderTime.hour,
        minute: state.reminderTime.minute,
      );
    } else {
      await NotificationService.instance.cancelAll();
    }
    state = state.copyWith(notificationsEnabled: value);
    _triggerSync();
  }

  Future<void> toggleSoundEffects(bool value) async {
    await settingsService.setSoundEffectsEnabled(value);
    state = state.copyWith(soundEffectsEnabled: value);
    _triggerSync();
  }

  Future<void> toggleHaptics(bool value) async {
    await settingsService.setHapticsEnabled(value);
    state = state.copyWith(hapticsEnabled: value);
    _triggerSync();
  }

  Future<void> setDailyWordGoal(int goal) async {
    await settingsService.setDailyWordGoal(goal);
    state = state.copyWith(dailyWordGoal: goal);
    _triggerSync();
  }

  Future<void> setCloudSyncEnabled(bool value) async {
    await settingsService.setCloudSyncEnabled(value);
    state = state.copyWith(cloudSyncEnabled: value);
    if (value) _triggerSync();
  }

  Future<void> setReminderTime(TimeOfDay time) async {
    await settingsService.setReminderTime(time);
    if (state.notificationsEnabled) {
      await NotificationService.instance.scheduleDailyReminder(
        hour: time.hour,
        minute: time.minute,
      );
    }
    state = state.copyWith(reminderTime: time);
    _triggerSync();
  }

  Future<void> setNativeLanguageCode(String code) async {
    await settingsService.setNativeLanguageCode(code);
    state = state.copyWith(nativeLanguageCode: code);
    _triggerSync();
  }

  Future<void> setAmbientTrack(String track) async {
    await settingsService.setSelectedAmbientTrack(track);
    state = state.copyWith(selectedAmbientTrack: track);
    _triggerSync();
  }

  Future<void> setBrainwaveType(String type) async {
    await settingsService.setSelectedBrainwaveType(type);
    state = state.copyWith(selectedBrainwaveType: type);
    _triggerSync();
  }

  void _triggerSync() {
    if (state.cloudSyncEnabled) {
      SyncManager().syncToCloud();
    }
  }
}

final databaseProvider = Provider<DatabaseHelper>((ref) => DatabaseHelper());

final usageServiceProvider = Provider<UsageService>((ref) => UsageService());

final authStateProvider = StreamProvider<AuthState>((ref) async* {
  // Emit initial state immediately
  final session = Supabase.instance.client.auth.currentSession;
  yield AuthState(
    session == null
        ? AuthChangeEvent.signedOut
        : AuthChangeEvent.initialSession,
    session,
  );
  // Then yield all subsequent events
  yield* Supabase.instance.client.auth.onAuthStateChange;
});

final currentLanguageProvider = Provider<String>((ref) {
  final active = ref.watch(courseProvider).activeCourse;
  return active?.targetLanguage.code ?? 'es';
});

final nativeLanguageProvider = Provider<String>((ref) {
  final active = ref.watch(courseProvider).activeCourse;
  return active?.nativeLanguage.code ?? 'en';
});
final isPremiumProvider = StreamProvider<bool>((ref) {
  return SubscriptionService().premiumStateStream;
});
final showPronunciationProvider = StateProvider<bool>((ref) => false);

final wordsForStudyProvider = FutureProvider<List<Word>>((ref) async {
  final db = ref.watch(databaseProvider);
  final targetLang = ref.watch(currentLanguageProvider);
  final nativeLang = ref.watch(nativeLanguageProvider);

  return await db.getWordsForLanguage(nativeLang, targetLang, limit: 20);
});

/// Provides real user profile data (name, email, avatar).
final userProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final user = AuthService().currentUser;
  if (user == null) return {'display_name': 'Guest Learner'};

  try {
    final response = await SupabaseConfig.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (response != null) return response;

    // Fallback to auth metadata
    return {
      'display_name': user.userMetadata?['display_name'] ?? 'Guest Learner',
      'email': user.email,
    };
  } catch (e) {
    debugPrint('Error fetching profile: $e');
    return {
      'display_name': user.userMetadata?['display_name'] ?? 'Guest Learner',
      'email': user.email,
    };
  }
});

final userStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final db = ref.watch(databaseProvider);
  final targetLang = ref.watch(currentLanguageProvider);
  final nativeLang = ref.watch(nativeLanguageProvider);
  final settings = ref.watch(settingsProvider);

  final totalLearned = await db.getTotalWordsLearned(targetLang);
  final dailyProgress = await db.getWordsReviewedToday(nativeLang, targetLang);
  final stats = await db.getUserStats();
  final usage = await db.getDailyUsage();

  return {
    'totalLearned': totalLearned,
    'currentStreak': stats['currentStreak'] ?? 0,
    'totalMinutes': stats['totalStudyMinutes'] ?? 0,
    'dailyGoal': settings.dailyWordGoal,
    'dailyProgress': dailyProgress,
    'sentencesToday': usage['sentences_played'] ?? 0,
    'reviewSecondsToday': usage['review_seconds'] ?? 0,
  };
});

final categoryStatsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final db = ref.watch(databaseProvider);
  final targetLang = ref.watch(currentLanguageProvider);
  final nativeLang = ref.watch(nativeLanguageProvider);

  return await db.getCategoryStats(nativeLang, targetLang);
});

final posStatsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final db = ref.watch(databaseProvider);
  final targetLang = ref.watch(currentLanguageProvider);
  final nativeLang = ref.watch(nativeLanguageProvider);

  return await db.getPOSStats(nativeLang, targetLang);
});

final recentActivityProvider = FutureProvider<List<Word>>((ref) async {
  final db = ref.watch(databaseProvider);
  final targetLang = ref.watch(currentLanguageProvider);
  final nativeLang = ref.watch(nativeLanguageProvider);

  return await db.getRecentActivity(nativeLang, targetLang);
});

final gardenJournalProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  return await DatabaseHelper().getRecentUserActivities(limit: 30);
});

final weeklyStudyStatsProvider = FutureProvider<Map<String, List<double>>>((
  ref,
) async {
  return await DatabaseHelper().getWeeklyStudyStats();
});





/// The three modes the Smart Focus Hub can display.
enum FocusMode { watering, resume, discover }

/// Aggregated state for the Smart Focus Hub.
class FocusState {
  final FocusMode mode;
  final int dueCount;
  final int totalLearned;
  final String? lastDomain;
  final String? lastSubDomain;
  final String? displayName;

  const FocusState({
    required this.mode,
    this.dueCount = 0,
    this.totalLearned = 0,
    this.lastDomain,
    this.lastSubDomain,
    this.displayName,
  });
}

final smartFocusProvider = FutureProvider<FocusState>((ref) async {
  final db = ref.watch(databaseProvider);
  final targetLang = ref.watch(currentLanguageProvider);
  final nativeLang = ref.watch(nativeLanguageProvider);

  // Priority 1: SRS review due?
  final dueCount = await db.getDueCount(nativeLang, targetLang);
  final totalLearned = await db.getTotalWordsLearned(targetLang);

  if (dueCount > 0) {
    return FocusState(
      mode: FocusMode.watering, 
      dueCount: dueCount,
      totalLearned: totalLearned,
    );
  }

  // Priority 2: Resume last active sub-theme
  final lastSubTheme = await db.getLastActiveSubTheme(nativeLang, targetLang);
  if (lastSubTheme != null && lastSubTheme['subDomain'] != null) {
    final rawSub = lastSubTheme['subDomain']!;
    // Convert snake_case id back to a readable name
    final displayName = rawSub
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '',
        )
        .join(' ');
    return FocusState(
      mode: FocusMode.resume,
      lastDomain: lastSubTheme['domain'],
      lastSubDomain: rawSub,
      displayName: displayName,
      totalLearned: totalLearned,
    );
  }

  return FocusState(
    mode: FocusMode.discover,
    lastDomain: 'people',
    lastSubDomain: 'identity',
    displayName: 'People & Identity',
    totalLearned: totalLearned,
  );
});

final dailyChallengesProvider = FutureProvider<List<DailyChallenge>>((
  ref,
) async {
  final stats = ref.watch(userStatsProvider).value;
  if (stats == null) return [];

  return await DailyChallengeManager.getDailyChallenges();
});

final podcastServiceProvider = ChangeNotifierProvider<PodcastService>((ref) {
  return PodcastService.instance;
});
