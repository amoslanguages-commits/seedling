import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../services/subscription_service.dart';
import '../providers/review_provider.dart';

class UsageService {
  static final UsageService _instance = UsageService._internal();
  factory UsageService() => _instance;
  UsageService._internal();

  static const int wordLimit = 5;
  static const int sentenceLimit = 30; // 30 sentences a day
  static const int reviewLimitSeconds = 1800; // 30 minutes a day

  Future<bool> canPlantWord() async {
    if (SubscriptionService().isPremium) return true;
    final usage = await DatabaseHelper().getDailyUsage();
    return (usage['words_planted'] ?? 0) < wordLimit;
  }

  Future<bool> canPlaySentence() async {
    if (SubscriptionService().isPremium) return true;
    final usage = await DatabaseHelper().getDailyUsage();
    return (usage['sentences_played'] ?? 0) < sentenceLimit;
  }

  Future<bool> canReview() async {
    if (SubscriptionService().isPremium) return true;
    final usage = await DatabaseHelper().getDailyUsage();
    return (usage['review_seconds'] ?? 0) < reviewLimitSeconds;
  }


  Future<void> logWordPlanted() async {
    await DatabaseHelper().incrementDailyUsage('words_planted');
  }

  Future<void> logSentencePlayed() async {
    await DatabaseHelper().incrementDailyUsage('sentences_played');
  }

  Future<void> logReviewTime(int seconds) async {
    if (seconds <= 0) return;
    await DatabaseHelper().incrementDailyUsage('review_seconds', amount: seconds);
  }

  // --- Session Resumption ---
  static const String _sessionKey = 'draft_review_session';

  Future<void> saveDraftSession(ReviewSessionState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(state.toJson()));
  }

  Future<ReviewSessionState?> loadDraftSession() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_sessionKey);
    if (data == null) return null;
    try {
      return ReviewSessionState.fromMap(jsonDecode(data));
    } catch (_) {
      return null;
    }
  }

  Future<void> clearDraftSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }
}
