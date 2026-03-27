import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../core/supabase_config.dart';
import '../database/database_helper.dart';
import 'auth_service.dart';

// ================ SYNC MANAGER ================

enum SyncStatus { idle, syncing, error, completed }

class SyncManager {
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal() {
    _loadPendingOperations();
  }
  
  Future<void> initialize() async {
    // Initial sync check
    if (AuthService().isAuthenticated) {
      syncFromCloud();
    }
  }
  
  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatus => _syncStatusController.stream;
  
  bool _isSyncing = false;
  List<SyncOperation> _pendingOperations = [];
  
  Future<void> syncToCloud() async {
    if (_isSyncing || !AuthService().isAuthenticated) return;
    
    _isSyncing = true;
    _syncStatusController.add(SyncStatus.syncing);
    
    try {
      final db = DatabaseHelper();
      final userId = AuthService().userId;
      
      // Sync word progress
      await _syncWordProgress(db, userId!);
      
      // Sync user stats
      await _syncUserStats(db, userId);
      
      // Sync study sessions
      await _syncStudySessions(db, userId);
      
      // Process pending operations
      await _processPendingOperations();
      
      _syncStatusController.add(SyncStatus.completed);
      debugPrint('Sync to cloud successful');
    } catch (e) {
      debugPrint('Sync error: $e');
      _syncStatusController.add(SyncStatus.error);
    } finally {
      _isSyncing = false;
    }
  }
  
  // Sync word progress
  Future<void> _syncWordProgress(DatabaseHelper db, String userId) async {
    final localWords = await db.getAllWordsWithProgress();
    if (localWords.isEmpty) return;
    
    final upsertData = localWords.map((word) => {
      'user_id': userId,
      'word_id': word.id,
      'mastery_level': word.masteryLevel,
      'last_reviewed': word.lastReviewed?.toIso8601String(),
      'streak': word.streak,
    }).toList();

    await SupabaseConfig.client.from('user_words').upsert(upsertData);
  }
  
  // Sync user stats
  Future<void> _syncUserStats(DatabaseHelper db, String userId) async {
    final stats = await db.getUserStats();
    if (stats.isNotEmpty) {
      await SupabaseConfig.client.from('user_stats').upsert({
        'user_id': userId,
        'total_xp': stats['totalWordsLearned'] * 10, // Example calculation
        'current_streak': stats['currentStreak'],
        'longest_streak': stats['longestStreak'],
        'total_study_minutes': stats['totalStudyMinutes'],
        'last_updated': DateTime.now().toIso8601String(),
      });
    }
  }
  
  // Sync study sessions
  Future<void> _syncStudySessions(DatabaseHelper db, String userId) async {
    final unsyncedSessions = await db.getUnsyncedStudySessions();
    
    for (final session in unsyncedSessions) {
      await SupabaseConfig.client.from('study_sessions').insert({
        'user_id': userId,
        'start_time': session['start_time'],
        'end_time': session['end_time'],
        'words_learned': session['words_learned'],
        'correct_answers': session['correct_answers'],
        'xp_gained': session['xp_gained'],
      });
      
      await db.markSessionAsSynced(session['id']);
    }
  }

  Future<void> syncFromCloud() async {
    if (_isSyncing || !AuthService().isAuthenticated) return;
    
    _isSyncing = true;
    _syncStatusController.add(SyncStatus.syncing);
    
    try {
      final db = DatabaseHelper();
      final userId = AuthService().userId;
      
      // Download word progress
      final cloudWords = await SupabaseConfig.client
          .from('user_words')
          .select()
          .eq('user_id', userId!);
      
      for (final cloudWord in cloudWords) {
        await db.updateWordProgress(
          cloudWord['word_id'],
          cloudWord['mastery_level'],
          cloudWord['streak'],
        );
      }
      
      // Download user stats
      final cloudStats = await SupabaseConfig.client
          .from('user_stats')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      
      if (cloudStats != null) {
        await db.updateUserStats({
          'totalWordsLearned': cloudStats['total_xp'] ~/ 10,
          'currentStreak': cloudStats['current_streak'],
          'longestStreak': cloudStats['longest_streak'],
          'totalStudyMinutes': cloudStats['total_study_minutes'],
        });
      }
      
      _syncStatusController.add(SyncStatus.completed);
      debugPrint('Sync from cloud successful');
    } catch (e) {
      debugPrint('Download error: $e');
      _syncStatusController.add(SyncStatus.error);
    } finally {
      _isSyncing = false;
    }
  }
  
  // Queue operation for later sync
  void queueOperation(SyncOperation operation) {
    _pendingOperations.add(operation);
    _savePendingOperations();
  }
  
  Future<void> _processPendingOperations() async {
    final List<SyncOperation> remaining = [];
    
    for (final operation in _pendingOperations) {
      try {
        await operation.execute();
      } catch (e) {
        remaining.add(operation);
      }
    }
    
    _pendingOperations = remaining;
    _savePendingOperations();
  }
  
  Future<void> _savePendingOperations() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _pendingOperations.map((o) => jsonEncode(o.toJson())).toList();
    await prefs.setStringList('pending_sync_operations', jsonList);
  }
  
  Future<void> _loadPendingOperations() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList('pending_sync_operations') ?? [];
    if (jsonList.isNotEmpty) {
       debugPrint('Pending operations found: ${jsonList.length}');
    }
  }
}

abstract class SyncOperation {
  Future<void> execute();
  Map<String, dynamic> toJson();
}
