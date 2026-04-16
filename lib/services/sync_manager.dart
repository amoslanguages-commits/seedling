import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;
import '../models/word.dart';
import '../core/supabase_config.dart';
import '../database/database_helper.dart';
import 'auth_service.dart';
import 'offline_queue_manager.dart';
import 'settings_service.dart';
import 'subscription_service.dart';

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
  int _retryCount = 0;
  Timer? _retryTimer;
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

      // Sync user preferences
      await _syncUserPreferences(userId);

      // Sync courses
      await _syncCourses(userId);

      // Process pending operations
      await _processPendingOperations();

      _retryCount = 0; // Reset retry count on success
      _syncStatusController.add(SyncStatus.completed);
      debugPrint('Sync to cloud successful');
    } catch (e) {
      debugPrint('Sync error: $e');
      _syncStatusController.add(SyncStatus.error);
      _scheduleRetry();
    } finally {
      _isSyncing = false;
    }
  }

  void _scheduleRetry() {
    if (_retryCount >= 10) return; // Max retries
    
    _retryCount++;
    // Exponential backoff: 2, 4, 8, 16, 32... seconds up to 1 hour
    final seconds = math.min(3600, math.pow(2, _retryCount).toInt());
    
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: seconds), () {
      syncToCloud();
    });
    
    debugPrint('Scheduled sync retry in $seconds seconds (Attempt $_retryCount)');
  }

  // Sync word progress
  Future<void> _syncWordProgress(DatabaseHelper db, String userId) async {
    final dirtyWords = await db.getDirtyWords();
    if (dirtyWords.isEmpty) return;

    final upsertData = dirtyWords
        .map(
          (word) => {
            'user_id': userId,
            'word_id': word.id,
            'mastery_level': word.masteryLevel,
            'last_reviewed': word.lastReviewed?.toIso8601String(),
            'streak': word.streak,
            'fsrs_stability': word.fsrsStability,
            'fsrs_difficulty': word.fsrsDifficulty,
            'fsrs_reps': word.fsrsReps,
            'fsrs_lapses': word.fsrsLapses,
            'fsrs_state': word.fsrsState,
            'next_review': word.nextReview?.toIso8601String(),
          },
        )
        .toList();

    try {
      await SupabaseConfig.client
          .from('user_words')
          .upsert(upsertData, onConflict: 'user_id, word_id');
      
      // Clear dirty flags locally after successful upload
      await db.clearDirtyFlags('words', dirtyWords.map((w) => w.id!).toList());
    } catch (e) {
      debugPrint('Error syncing word progress to cloud: $e');
      rethrow; // Propagate to trigger retry
    }
  }

  // Sync user stats
  Future<void> _syncUserStats(DatabaseHelper db, String userId) async {
    final stats = await db.getUserStats();
    
    // To be fully delta-based, let's only sync if the user_progress row is dirty.
    final rawProgress = await db.database.then((d) => d.query('user_progress', limit: 1));
    if (rawProgress.isEmpty || rawProgress.first['is_dirty'] == 0) return;

    try {
      await SupabaseConfig.client.from('user_stats').upsert({
        'user_id': userId,
        'total_xp': stats['totalXP'] ?? 0,
        'current_streak': stats['currentStreak'],
        'longest_streak': stats['longestStreak'],
        'total_study_minutes': stats['totalStudyMinutes'],
        'total_words_learned': stats['totalWordsLearned'] ?? 0,
        'last_updated': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
      
      await db.clearUserProgressDirtyFlag();
    } catch (e) {
      debugPrint('Error syncing user stats to cloud: $e');
      rethrow; // Trigger retry
    }
  }

  // Sync study sessions
  Future<void> _syncStudySessions(DatabaseHelper db, String userId) async {
    final unsyncedSessions = await db.getUnsyncedStudySessions();

    for (final session in unsyncedSessions) {
      try {
        final sessionDateStr = session['session_date'] as String;
        final sessionDate = DateTime.parse(sessionDateStr);
        final duration = session['duration_minutes'] as int? ?? 0;
        final endTime = sessionDate.add(Duration(minutes: duration));

        await SupabaseConfig.client.from('study_sessions').insert({
          'user_id': userId,
          'start_time': sessionDate.toIso8601String(),
          'end_time': endTime.toIso8601String(),
          'words_learned': session['words_studied'] ?? 0,
          'correct_answers': session['correct_answers'] ?? 0,
          'xp_gained': session['xp_gained'] ?? 0,
        });

        await db.markSessionAsSynced(session['id']);
      } catch (e) {
        debugPrint('Error syncing session ${session['id']}: $e');
      }
    }
  }

  // Sync user preferences
  Future<void> _syncUserPreferences(String userId) async {
    try {
      final settings = SettingsService();
      await SupabaseConfig.client.from('user_preferences').upsert({
        'user_id': userId,
        'notifications_enabled': settings.notificationsEnabled,
        'sound_effects_enabled': settings.soundEffectsEnabled,
        'haptics_enabled': settings.hapticsEnabled,
        'daily_word_goal': settings.dailyWordGoal,
        'reminder_hour': settings.reminderHour,
        'reminder_minute': settings.reminderMinute,
        'cloud_sync_enabled': settings.cloudSyncEnabled,
        'native_language_code': settings.nativeLanguageCode,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error syncing preferences: $e');
    }
  }

  Future<void> _downloadUserPreferences(String userId) async {
    try {
      final data = await SupabaseConfig.client
          .from('user_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (data != null) {
        final settings = SettingsService();
        await settings.setNotificationsEnabled(data['notifications_enabled'] == true);
        await settings.setSoundEffectsEnabled(data['sound_effects_enabled'] == true);
        await settings.setHapticsEnabled(data['haptics_enabled'] == true);
        await settings.setDailyWordGoal(int.tryParse(data['daily_word_goal']?.toString() ?? '') ?? 10);
        // Note: TimeOfDay needs careful handling as it's not a primitive
        // We'll trust the integer values from the DB
        await settings.setReminderTime(
          TimeOfDay(
            hour: int.tryParse(data['reminder_hour']?.toString() ?? '') ?? 8,
            minute: int.tryParse(data['reminder_minute']?.toString() ?? '') ?? 0,
          ),
        );
        await settings.setCloudSyncEnabled(data['cloud_sync_enabled']);
        await settings.setNativeLanguageCode(data['native_language_code'] ?? 'en');
      }
    } catch (e) {
      debugPrint('Error downloading preferences: $e');
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
        // Construct a word-like map for FSRS update
        final wordToUpdate = Word.fromMap({
          ...cloudWord,
          'id': cloudWord['word_id'],
        });
        await db.updateWordFSRS(wordToUpdate);
      }

      // Download user stats
      final cloudStats = await SupabaseConfig.client
          .from('user_stats')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (cloudStats != null) {
        await db.updateUserStats({
          'totalWordsLearned': int.tryParse(cloudStats['total_words_learned']?.toString() ?? '') ?? 0,
          'totalXP': int.tryParse(cloudStats['total_xp']?.toString() ?? '') ?? 0,
          'currentStreak': int.tryParse(cloudStats['current_streak']?.toString() ?? '') ?? 0,
          'longestStreak': int.tryParse(cloudStats['longest_streak']?.toString() ?? '') ?? 0,
          'totalStudyMinutes': int.tryParse(cloudStats['total_study_minutes']?.toString() ?? '') ?? 0,
        });
      }

      // Download user preferences
      await _downloadUserPreferences(userId);

      // Download courses
      await _downloadCourses(userId);

      // Verify and sync entitlement status
      await SubscriptionService().checkSubscription();

      _syncStatusController.add(SyncStatus.completed);
      debugPrint('Sync from cloud successful');
    } catch (e) {
      debugPrint('Download error: $e');
      _syncStatusController.add(SyncStatus.error);
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncCourses(String userId) async {
    try {
      final db = DatabaseHelper();
      final localCourses = await db.getCourses(userId);
      final dirtyCourses = localCourses.where((c) => c['is_dirty'] == 1).toList();

      if (dirtyCourses.isEmpty) return;

      final upsertData = dirtyCourses.map((c) => {
        'id': c['id'],
        'user_id': userId,
        'native_lang_code': c['native_lang_code'],
        'target_lang_code': c['target_lang_code'],
        'is_active': c['is_active'] == 1,
        'updated_at': DateTime.now().toIso8601String(),
      }).toList();

      await SupabaseConfig.client
          .from('courses')
          .upsert(upsertData, onConflict: 'id');

      await db.clearDirtyFlags('courses', dirtyCourses.map((c) => c['id']).toList());
    } catch (e) {
      debugPrint('Error syncing courses: $e');
    }
  }

  Future<void> _downloadCourses(String userId) async {
    try {
      final cloudCourses = await SupabaseConfig.client
          .from('courses')
          .select()
          .eq('user_id', userId);

      final db = DatabaseHelper();
      for (final c in cloudCourses) {
        await db.saveCourse({
          'id': c['id'],
          'user_id': userId,
          'native_lang_code': c['native_lang_code'],
          'target_lang_code': c['target_lang_code'],
          'is_active': c['is_active'] == true ? 1 : 0,
          'is_dirty': 0, // Mark as clean after download
        });
      }
    } catch (e) {
      debugPrint('Error downloading courses: $e');
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
    final jsonList = _pendingOperations
        .map((o) => jsonEncode(o.toJson()))
        .toList();
    await prefs.setStringList('pending_sync_operations', jsonList);
  }

  Future<void> _loadPendingOperations() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList('pending_sync_operations') ?? [];
    if (jsonList.isEmpty) return;

    final List<SyncOperation> loaded = [];
    for (final jsonStr in jsonList) {
      try {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        final String type = data['type'] ?? '';

        switch (type) {
          case 'mastery_update':
            loaded.add(MasteryUpdateOperation.fromJson(data));
            break;
          case 'confusion_record':
            loaded.add(ConfusionRecordOperation.fromJson(data));
            break;
          case 'quiz_performance':
            loaded.add(QuizPerformanceOperation.fromJson(data));
            break;
        }
      } catch (e) {
        debugPrint('Error decoding pending operation: $e');
      }
    }
    _pendingOperations = loaded;
    if (_pendingOperations.isNotEmpty) {
      debugPrint('Pending operations recovered: ${_pendingOperations.length}');
      // Trigger sync if we have connectivity
      syncToCloud();
    }
  }
}

abstract class SyncOperation {
  Future<void> execute();
  Map<String, dynamic> toJson();
}
