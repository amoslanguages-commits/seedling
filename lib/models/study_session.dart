class StudySession {
  final int? id;
  final String userId;
  final String languageCode;
  final DateTime sessionDate;
  final int wordsStudied;
  final int correctAnswers;
  final int durationMinutes;
  final bool isSynced;
  
  StudySession({
    this.id,
    required this.userId,
    required this.languageCode,
    required this.sessionDate,
    required this.wordsStudied,
    required this.correctAnswers,
    required this.durationMinutes,
    this.isSynced = false,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'language_code': languageCode,
      'session_date': sessionDate.toIso8601String(),
      'words_studied': wordsStudied,
      'correct_answers': correctAnswers,
      'duration_minutes': durationMinutes,
      'is_synced': isSynced ? 1 : 0,
    };
  }
  
  factory StudySession.fromMap(Map<String, dynamic> map) {
    return StudySession(
      id: map['id'],
      userId: map['user_id'],
      languageCode: map['language_code'],
      sessionDate: DateTime.parse(map['session_date']),
      wordsStudied: map['words_studied'] ?? 0,
      correctAnswers: map['correct_answers'] ?? 0,
      durationMinutes: map['duration_minutes'] ?? 0,
      isSynced: (map['is_synced'] ?? 0) == 1,
    );
  }
}
