import '../database/database_helper.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.isUnlocked,
    this.unlockedAt,
  });
}

class DailyChallenge {
  final String id;
  final String title;
  final double progress;
  final double goal;
  final int xpReward;

  DailyChallenge({
    required this.id,
    required this.title,
    required this.progress,
    required this.goal,
    required this.xpReward,
  });

  bool get isCompleted => progress >= goal;
}

class DailyChallengeManager {
  static Future<List<DailyChallenge>> getDailyChallenges() async {
    final stats = await DatabaseHelper().getUserStats();
    final wordsToday = stats['wordsReviewedToday'] as int? ?? 0;
    final studyMinutes = stats['totalStudyMinutes'] as int? ?? 0;
    // For "perfect accuracy", we'll use a heuristic or just a high-level stat for now
    // as we don't track per-quiz perfection in the aggregate yet.

    return [
      DailyChallenge(
        id: 'challenge_1',
        title: 'Learn 5 new words',
        progress: wordsToday.toDouble(),
        goal: 5,
        xpReward: 50,
      ),
      DailyChallenge(
        id: 'challenge_2',
        title: 'Study session completion',
        progress: (stats['totalSessions'] ?? 0) > 0 ? 1 : 0,
        goal: 1,
        xpReward: 100,
      ),
      DailyChallenge(
        id: 'challenge_3',
        title: 'Active Learning',
        progress: studyMinutes.toDouble(),
        goal: 15,
        xpReward: 75,
      ),
    ];
  }
}

class StreakManager {
  static Future<int> getCurrentStreak() async {
    final stats = await DatabaseHelper().getUserStats();
    return stats['currentStreak'] as int? ?? 0;
  }
}

class XPManager {
  static Future<(int, int, int)> getLevelProgress() async {
    final stats = await DatabaseHelper().getUserStats();
    final int points = stats['totalXP'] as int? ?? 0;
    const int xpPerLevel = 1000;

    int level = (points / xpPerLevel).floor() + 1;
    int currentXP = points % xpPerLevel;

    return (level, currentXP, xpPerLevel);
  }
}

class AchievementManager {
  static Future<List<Achievement>> getAchievements() async {
    final stats = await DatabaseHelper().getUserStats();
    final totalWords = stats['totalWordsLearned'] as int? ?? 0;
    final streak = stats['currentStreak'] as int? ?? 0;
    final totalXP = stats['totalXP'] as int? ?? 0;
    final level = (totalXP / 1000).floor() + 1;

    return [
      Achievement(
        id: 'first_steps',
        title: 'First Steps',
        description: 'Learn your first 10 words',
        icon: '🌱',
        isUnlocked: totalWords >= 10,
      ),
      Achievement(
        id: 'streak_7',
        title: 'Week Warrior',
        description: 'Maintain a 7-day streak',
        icon: '🔥',
        isUnlocked: streak >= 7,
      ),
      Achievement(
        id: 'polyglot',
        title: 'Polyglot',
        description: 'Earn 5000 total XP',
        icon: '🌍',
        isUnlocked: totalXP >= 5000,
      ),
      Achievement(
        id: 'top_learner',
        title: 'Top Learner',
        description: 'Reach Level 10',
        icon: '🏆',
        isUnlocked: level >= 10,
      ),
    ];
  }
}
