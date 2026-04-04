import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../core/supabase_config.dart';
import '../database/database_helper.dart';
import 'auth_service.dart';
import 'offline_queue_manager.dart';
import 'settings_service.dart';
import 'package:flutter/material.dart' show TimeOfDay;

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

      // Sync user preferences
      await _syncUserPreferences(userId);

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

    final upsertData = localWords
        .map(
          (word) => {
            'user_id': userId,
            'word_id': word.id,
            'mastery_level': word.masteryLevel,
            'last_reviewed': word.lastReviewed?.toIso8601String(),
            'streak': word.streak,
          },
        )
        .toList();

    await SupabaseConfig.client.from('user_words').upsert(upsertData);
  }

  // Sync user stats
  Future<void> _syncUserStats(DatabaseHelper db, String userId) async {
    final stats = await db.getUserStats();
    if (stats.isNotEmpty) {
      await SupabaseConfig.client.from('user_stats').upsert({
        'user_id': userId,
        'total_xp': stats['totalXP'] ?? 0,
        'current_streak': stats['currentStreak'],
        'longest_streak': stats['longestStreak'],
        'total_study_minutes': stats['totalStudyMinutes'],
        'total_words_learned': stats['totalWordsLearned'] ?? 0,
        'last_updated': DateTime.now().toIso8601String(),
      });
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
        print('Error syncing session ${session['id']}: $e');
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
        await settings.setNotificationsEnabled(data['notifications_enabled']);
        await settings.setSoundEffectsEnabled(data['sound_effects_enabled']);
        await settings.setHapticsEnabled(data['haptics_enabled']);
        await settings.setDailyWordGoal(data['daily_word_goal']);
        // Note: TimeOfDay needs careful handling as it's not a primitive
        // We'll trust the integer values from the DB
        await settings.setReminderTime(TimeOfDay(
          hour: data['reminder_hour'],
          minute: data['reminder_minute'],
        ));
        await settings.setCloudSyncEnabled(data['cloud_sync_enabled']);
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
          'totalWordsLearned': cloudStats['total_words_learned'] ?? 0,
          'totalXP': cloudStats['total_xp'] ?? 0,
          'currentStreak': cloudStats['current_streak'] ?? 0,
          'longestStreak': cloudStats['longest_streak'] ?? 0,
          'totalStudyMinutes': cloudStats['total_study_minutes'] ?? 0,
        });
      }

      // Download user preferences
      await _downloadUserPreferences(userId);

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
