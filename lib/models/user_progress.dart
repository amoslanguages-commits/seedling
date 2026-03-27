class UserProgress {
  final String userId;
  final String learningLanguage;
  final String nativeLanguage;
  final int totalWordsLearned;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastStudySession;
  final int totalStudyMinutes;
  final bool isPremium;
  
  UserProgress({
    required this.userId,
    required this.learningLanguage,
    required this.nativeLanguage,
    this.totalWordsLearned = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastStudySession,
    this.totalStudyMinutes = 0,
    this.isPremium = false,
  });
}
