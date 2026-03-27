import '../database/database_helper.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final DateTime? unlockedAt;
  
  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.unlockedAt,
  });
  
  bool get isUnlocked => unlockedAt != null;
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
  static List<DailyChallenge> generateDailyChallenges() {
    return [
      DailyChallenge(
        id: 'challenge_1',
        title: 'Learn 5 new words',
        progress: 3,
        goal: 5,
        xpReward: 50,
      ),
      DailyChallenge(
        id: 'challenge_2',
        title: 'Perfect accuracy in 2 quizzes',
        progress: 1,
        goal: 2,
        xpReward: 100,
      ),
      DailyChallenge(
        id: 'challenge_3',
        title: 'Study for 15 minutes',
        progress: 10,
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
    // 10 XP per total word learned + 5 XP per study minute
    final stats = await DatabaseHelper().getUserStats();
    final int wordsL = stats['totalWordsLearned'] as int? ?? 0;
    final int minutes = stats['totalStudyMinutes'] as int? ?? 0;
    
    final int totalXP = (wordsL * 10) + (minutes * 5);
    const int xpPerLevel = 1000;
    
    int level = (totalXP / xpPerLevel).floor() + 1;
    int currentXP = totalXP % xpPerLevel;
    
    return (level, currentXP, xpPerLevel);
  }
}

class AchievementManager {
  static List<Achievement> get achievements => [
    Achievement(
      id: 'first_steps',
      title: 'First Steps',
      description: 'Learn your first 10 words',
      icon: '🌱',
      unlockedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    Achievement(
      id: 'streak_7',
      title: 'Week Warrior',
      description: 'Maintain a 7-day streak',
      icon: '🔥',
      unlockedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Achievement(
      id: 'polyglot',
      title: 'Polyglot',
      description: 'Start learning a second language',
      icon: '🌍',
    ),
    Achievement(
      id: 'top_learner',
      title: 'Top Learner',
      description: 'Reach Level 10',
      icon: '🏆',
    ),
  ];
}
