import 'dart:async';
import 'sync_manager.dart';
import 'auth_service.dart';
import '../core/supabase_config.dart';

// ================ OFFLINE QUEUE MANAGER ================

class OfflineQueueManager {
  static final OfflineQueueManager _instance = OfflineQueueManager._internal();
  factory OfflineQueueManager() => _instance;
  OfflineQueueManager._internal();

  void addOperation(SyncOperation operation) {
    SyncManager().queueOperation(operation);
  }

  // High-level methods for common operations
  void queueMasteryUpdate(int wordId, bool correct) {
    addOperation(MasteryUpdateOperation(wordId: wordId, correct: correct));
  }

  void queueConfusionRecord(int wordId, int confusedWithId) {
    addOperation(
      ConfusionRecordOperation(wordId: wordId, confusedWithId: confusedWithId),
    );
  }

  void queueQuizPerformance(
    int wordId,
    String quizType,
    int responseMs,
    bool correct,
  ) {
    addOperation(
      QuizPerformanceOperation(
        wordId: wordId,
        quizType: quizType,
        responseMs: responseMs,
        correct: correct,
      ),
    );
  }
}

class MasteryUpdateOperation implements SyncOperation {
  final int wordId;
  final bool correct;

  MasteryUpdateOperation({required this.wordId, required this.correct});

  @override
  Future<void> execute() async {
    final userId = AuthService().userId;
    if (userId == null) return;

    await SupabaseConfig.client.from('mastery_updates').insert({
      'user_id': userId,
      'word_id': wordId,
      'correct': correct,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Also update the main user_words table
    await SupabaseConfig.client.rpc(
      'update_word_mastery',
      params: {'p_user_id': userId, 'p_word_id': wordId, 'p_correct': correct},
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'mastery_update',
    'wordId': wordId,
    'correct': correct,
  };

  factory MasteryUpdateOperation.fromJson(Map<String, dynamic> json) {
    return MasteryUpdateOperation(
      wordId: json['wordId'],
      correct: json['correct'],
    );
  }
}

class ConfusionRecordOperation implements SyncOperation {
  final int wordId;
  final int confusedWithId;

  ConfusionRecordOperation({
    required this.wordId,
    required this.confusedWithId,
  });

  @override
  Future<void> execute() async {
    final userId = AuthService().userId;
    if (userId == null) return;

    await SupabaseConfig.client.from('word_confusions').upsert({
      'user_id': userId,
      'word_id': wordId,
      'confused_with_id': confusedWithId,
      'last_confusion_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id, word_id, confused_with_id');
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'confusion_record',
    'wordId': wordId,
    'confusedWithId': confusedWithId,
  };

  factory ConfusionRecordOperation.fromJson(Map<String, dynamic> json) {
    return ConfusionRecordOperation(
      wordId: json['wordId'],
      confusedWithId: json['confusedWithId'],
    );
  }
}

class QuizPerformanceOperation implements SyncOperation {
  final int wordId;
  final String quizType;
  final int responseMs;
  final bool correct;

  QuizPerformanceOperation({
    required this.wordId,
    required this.quizType,
    required this.responseMs,
    required this.correct,
  });

  @override
  Future<void> execute() async {
    final userId = AuthService().userId;
    if (userId == null) return;

    await SupabaseConfig.client.from('word_quiz_performance').insert({
      'user_id': userId,
      'word_id': wordId,
      'quiz_type': quizType,
      'response_ms': responseMs,
      'correct': correct,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'quiz_performance',
    'wordId': wordId,
    'quizType': quizType,
    'responseMs': responseMs,
    'correct': correct,
  };

  factory QuizPerformanceOperation.fromJson(Map<String, dynamic> json) {
    return QuizPerformanceOperation(
      wordId: json['wordId'],
      quizType: json['quizType'],
      responseMs: json['responseMs'],
      correct: json['correct'],
    );
  }
}
