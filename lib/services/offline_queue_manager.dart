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
    await SupabaseConfig.client.rpc('update_word_mastery', params: {
      'p_user_id': userId,
      'p_word_id': wordId,
      'p_correct': correct,
    });
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
