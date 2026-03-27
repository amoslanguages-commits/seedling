import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_helper.dart';
import '../models/word.dart';
import '../services/social_service.dart';
import '../models/social.dart';
import 'course_provider.dart';

final databaseProvider = Provider<DatabaseHelper>((ref) => DatabaseHelper());
final socialServiceProvider = Provider<SocialService>((ref) => SocialService());

final authStateProvider = StreamProvider<AuthState>((ref) async* {
  // Emit initial state immediately
  final session = Supabase.instance.client.auth.currentSession;
  yield AuthState(
    session == null ? AuthChangeEvent.signedOut : AuthChangeEvent.initialSession,
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
final isPremiumProvider = StateProvider<bool>((ref) => false);

final wordsForStudyProvider = FutureProvider<List<Word>>((ref) async {
  final db = ref.watch(databaseProvider);
  final targetLang = ref.watch(currentLanguageProvider);
  final nativeLang = ref.watch(nativeLanguageProvider);
  
  return await db.getWordsForLanguage(
    nativeLang,
    targetLang,
    limit: 20,
  );
});

final userStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final db = ref.watch(databaseProvider);
  final targetLang = ref.watch(currentLanguageProvider);
  final nativeLang = ref.watch(nativeLanguageProvider);
  
  final totalLearned = await db.getTotalWordsLearned(targetLang);
  final dailyProgress = await db.getWordsReviewedToday(nativeLang, targetLang);
  final stats = await db.getUserStats();
  
  return {
    'totalLearned': totalLearned,
    'currentStreak': stats['currentStreak'] ?? 0,
    'totalMinutes': stats['totalStudyMinutes'] ?? 0,
    'dailyGoal': 10,
    'dailyProgress': dailyProgress, 
  };
});

final categoryStatsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  final targetLang = ref.watch(currentLanguageProvider);
  final nativeLang = ref.watch(nativeLanguageProvider);
  
  return await db.getCategoryStats(nativeLang, targetLang);
});

final posStatsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
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

final friendsProvider = FutureProvider<List<Friend>>((ref) async {
  final auth = ref.watch(authStateProvider);
  if (auth.value?.session == null) return [];
  return await ref.watch(socialServiceProvider).getFriends();
});

final pendingRequestsProvider = FutureProvider<List<Friend>>((ref) async {
  final auth = ref.watch(authStateProvider);
  if (auth.value?.session == null) return [];
  return await ref.watch(socialServiceProvider).getPendingRequests();
});

final competitionsProvider = FutureProvider<List<Competition>>((ref) async {
  final auth = ref.watch(authStateProvider);
  if (auth.value?.session == null) return [];
  return await ref.watch(socialServiceProvider).getCompetitions();
});
