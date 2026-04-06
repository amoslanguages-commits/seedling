import '../database/database_helper.dart';
import '../services/subscription_service.dart';

class UsageService {
  static final UsageService _instance = UsageService._internal();
  factory UsageService() => _instance;
  UsageService._internal();

  static const int wordLimit = 5;
  static const int sentenceLimit = 30;
  static const int hostLimit = 2;
  static const int joinLimit = 5;

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

  Future<bool> canHostGame() async {
    if (SubscriptionService().isPremium) return true;
    final usage = await DatabaseHelper().getDailyUsage();
    return (usage['games_hosted'] ?? 0) < hostLimit;
  }

  Future<bool> canJoinGame() async {
    if (SubscriptionService().isPremium) return true;
    final usage = await DatabaseHelper().getDailyUsage();
    return (usage['games_joined'] ?? 0) < joinLimit;
  }

  Future<void> logWordPlanted() async {
    await DatabaseHelper().incrementDailyUsage('words_planted');
  }

  Future<void> logSentencePlayed() async {
    await DatabaseHelper().incrementDailyUsage('sentences_played');
  }

  Future<void> logGameHosted() async {
    await DatabaseHelper().incrementDailyUsage('games_hosted');
  }

  Future<void> logGameJoined() async {
    await DatabaseHelper().incrementDailyUsage('games_joined');
  }
}
