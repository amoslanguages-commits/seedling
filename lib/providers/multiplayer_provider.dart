import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/multiplayer.dart';
import '../core/supabase_config.dart';
import '../services/auth_service.dart';
import '../providers/app_providers.dart';
import '../services/usage_service.dart';
import '../models/gamification.dart';
import '../database/database_helper.dart';

// --- Discovery Hub State ---

// Provides a list of all active games (lobby or playing) from Supabase
final activeGamesProvider = StreamProvider<List<LiveGameSession>>((ref) {
  return SupabaseConfig.client
      .from('live_sessions')
      .stream(primaryKey: ['id'])
      .map((data) {
        return data
            .where(
              (json) =>
                  json['status'] == 'lobby' && json['is_private'] == false,
            )
            .map((json) => LiveGameSession.fromJson(json))
            .toList();
      });
});

// Filtering state for Discovery Hub
final gameThemeFilterProvider = StateProvider<String?>((ref) => null);
final gameCourseFilterProvider = StateProvider<String?>(
  (ref) => 'All',
); // 'NativeCode_TargetCode' or 'All'
final gameModeFilterProvider = StateProvider<String>((ref) => 'All');

final filteredGamesProvider = Provider<List<LiveGameSession>>((ref) {
  final games = ref.watch(activeGamesProvider).value ?? [];
  final themeFilter = ref.watch(gameThemeFilterProvider);
  final courseFilter = ref.watch(gameCourseFilterProvider);
  final modeFilter = ref.watch(gameModeFilterProvider);

  return games.where((g) {
    // Theme Filter
    if (themeFilter != null && themeFilter != 'All' && g.theme != themeFilter) {
      return false;
    }

    // Course Filter (Native_Target)
    if (courseFilter != null && courseFilter != 'All') {
      final filterSplit = courseFilter.split('_');
      if (filterSplit.length == 2) {
        if (g.languageCode != filterSplit[0] ||
            g.targetLanguageCode != filterSplit[1]) {
          return false;
        }
      }
    }

    // Mode Filter
    if (modeFilter != 'All') {
      final isVocabMatch =
          modeFilter == 'Vocabulary' && g.gameType == LiveGameType.vocabulary;
      final isSentenceMatch =
          modeFilter == 'Sentences' && g.gameType == LiveGameType.sentences;
      if (!isVocabMatch && !isSentenceMatch) {
        return false;
      }
    }

    return true;
  }).toList();
});

// Provides the current user's active session for "Rejoin" functionality
final myActiveSessionProvider = StreamProvider<LiveGameSession?>((ref) {
  final userId = ref.watch(authStateProvider).value?.session?.user.id;
  if (userId == null) return Stream.value(null);

  return SupabaseConfig.client
      .from('live_participants')
      .stream(primaryKey: ['id'])
      .asyncMap((data) async {
        final filteredData = data.where((p) => p['user_id'] == userId).toList();
        if (filteredData.isEmpty) return null;

        // Find the most recent active session
        final sessionIds = filteredData
            .map((p) => p['session_id'] as String)
            .toList();

        final sessionResponse = await SupabaseConfig.client
            .from('live_sessions')
            .select()
            .inFilter('id', sessionIds)
            .not('status', 'in', '("finished", "terminated")')
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (sessionResponse == null) return null;
        return LiveGameSession.fromJson(sessionResponse);
      });
});

// --- Active Session Management ---

class ActiveGameNotifier extends StateNotifier<LiveGameSession?> {
  final Ref ref;
  RealtimeChannel? _channel;
  StreamSubscription? _sessionSub;
  StreamSubscription? _participantsSub;
  StreamSubscription? _messagesSub;

  // Callback for real-time reactions
  void Function(String emoji)? onReactionReceived;
  void Function(String type)? onPulseReceived;

  ActiveGameNotifier(this.ref) : super(null);

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  void _cleanup() {
    _sessionSub?.cancel();
    _participantsSub?.cancel();
    _messagesSub?.cancel();
    if (_channel != null) {
      SupabaseConfig.client.removeChannel(_channel!);
    }
  }

  // --- Core Lifecycle ---

  Future<void> hostGame(LiveGameSession session) async {
    _cleanup();

    final user = AuthService().currentUser;
    if (user == null) return;

    final targetLang = ref.read(currentLanguageProvider);
    final nativeLang = ref.read(nativeLanguageProvider);

    final canHost = await UsageService().canHostGame();
    if (!canHost) {
      throw Exception('PREMIUM_LIMIT_HOST');
    }

    final (level, _, _) = await XPManager.getLevelProgress();

    // 1. Create session in DB
    final response = await SupabaseConfig.client
        .from('live_sessions')
        .insert({
          'host_id': user.id,
          'host_name': user.userMetadata?['display_name'] ?? 'Host',
          'host_level': level,
          'host_avatar_emoji': user.userMetadata?['avatar_emoji'] ?? '👤',
          'title': session.title,
          'game_type': session.gameType.name,
          'max_players': session.maxPlayers,
          'question_count': session.totalQuestions,
          'time_per_question': session.timePerQuestion,
          'theme': session.theme,
          'subtheme': session.subtheme,
          'language_code': nativeLang,
          'target_language_code': targetLang,
          'status': 'lobby',
          'is_private': session.isPrivate,
          'is_duel': session.isDuel,
          'is_survival': session.isSurvival,
        })
        .select()
        .single();

    final newSessionId = response['id'];

    // 2. Add self as host participant
    await SupabaseConfig.client.from('live_participants').insert({
      'session_id': newSessionId,
      'user_id': user.id,
      'display_name': user.userMetadata?['display_name'] ?? 'Host',
      'avatar_emoji': '👑',
      'role': 'host',
      'level': level,
    });

    // 3. Connect listeners
    await _connectToSession(newSessionId);

    // 3.5 Manually set initial state to avoid race condition with stream
    state = LiveGameSession.fromJson(
      response,
      participants: [
        LivePlayer(
          id: user.id,
          displayName: user.userMetadata?['display_name'] ?? 'Host',
          avatarEmoji: '👑',
          role: PlayerRole.host,
          level: level,
        ),
      ],
    );

    // 4. Log usage
    await UsageService().logGameHosted();

    // 5. Increment permanent stats
    await DatabaseHelper().incrementTotalRoomsHosted();
    await DatabaseHelper().logActivity(
      type: 'competition_host',
      description: 'Hosted a new challenge: ${session.title}',
      xp: 50,
    );

    // Refresh competition header
    ref.invalidate(userCompeteStatsProvider);
  }

  Future<void> joinAsSpectator(LiveGameSession session) async {
    _cleanup();

    final user = AuthService().currentUser;
    if (user == null) return;

    // 1. Check if already participant
    final existing = await SupabaseConfig.client
        .from('live_participants')
        .select()
        .eq('session_id', session.id)
        .eq('user_id', user.id)
        .maybeSingle();

    if (existing == null) {
      // 2. Add as spectator
      await SupabaseConfig.client.from('live_participants').insert({
        'session_id': session.id,
        'user_id': user.id,
        'display_name': user.userMetadata?['display_name'] ?? 'Guest',
        'avatar_emoji': '🌱',
        'role': 'spectator',
      });
    }

    // 3. Connect listeners
    await _connectToSession(session.id);
  }

  Future<void> joinAsPlayer(LiveGameSession session) async {
    _cleanup();

    final user = AuthService().currentUser;
    if (user == null) return;

    // 1. Check if already participant
    final existing = await SupabaseConfig.client
        .from('live_participants')
        .select()
        .eq('session_id', session.id)
        .eq('user_id', user.id)
        .maybeSingle();

    if (existing == null) {
      final canJoin = await UsageService().canJoinGame();
      if (!canJoin) {
        throw Exception('PREMIUM_LIMIT_JOIN');
      }

      // 2. Add as player
      await SupabaseConfig.client.from('live_participants').insert({
        'session_id': session.id,
        'user_id': user.id,
        'display_name': user.userMetadata?['display_name'] ?? 'Player',
        'avatar_emoji': '⚔️',
        'role': 'player',
        'level': (await XPManager.getLevelProgress()).$1,
      });
    }

    // 3. Connect listeners
    await _connectToSession(session.id);
  }

  /// Reconnects to an existing session for "Rejoin" functionality
  Future<void> rejoinSession(String sessionId) async {
    _cleanup();
    await _connectToSession(sessionId);
  }

  Future<void> _connectToSession(String sessionId) async {
    // Session Stream
    _sessionSub = SupabaseConfig.client
        .from('live_sessions')
        .stream(primaryKey: ['id'])
        .eq('id', sessionId)
        .listen((data) {
          if (data.isEmpty) {
            state = null;
            return;
          }
          final sessionJson = data.first;
          _updateLocalState(sessionJson: sessionJson);
        });

    // Participants Stream
    _participantsSub = SupabaseConfig.client
        .from('live_participants')
        .stream(primaryKey: ['id'])
        .eq('session_id', sessionId)
        .listen((data) {
          final participants = data
              .map((json) => LivePlayer.fromJson(json))
              .toList();
          _updateLocalState(participants: participants);
        });

    // Messages Stream
    _messagesSub = SupabaseConfig.client
        .from('live_messages')
        .stream(primaryKey: ['id'])
        .eq('session_id', sessionId)
        .listen((data) {
          final messages = data
              .map((json) => LiveChatMessage.fromJson(json))
              .toList();
          _updateLocalState(messages: messages);
        });

    // Realtime Channel for Reactions (Broadcast)
    _channel = SupabaseConfig.client.channel('session_$sessionId');
    _channel!
        .onBroadcast(
          event: 'reaction',
          callback: (payload) {
            final emoji = payload['emoji'] as String?;
            if (emoji != null && onReactionReceived != null) {
              onReactionReceived!(emoji);
            }
          },
        )
        .onBroadcast(
          event: 'pulse',
          callback: (payload) {
            final type = payload['type'] as String?;
            if (type != null && onPulseReceived != null) {
              onPulseReceived!(type);
            }
          },
        )
        .subscribe();
  }

  void _updateLocalState({
    Map<String, dynamic>? sessionJson,
    List<LivePlayer>? participants,
    List<LiveChatMessage>? messages,
  }) {
    if (sessionJson == null && state == null) return;

    final currentSession = state;
    final json = sessionJson ?? {}; // If we only got participants update

    if (currentSession == null && sessionJson != null) {
      // Initial load
      state = LiveGameSession.fromJson(
        sessionJson,
        participants: participants ?? [],
        messages: messages ?? [],
      );
    } else if (currentSession != null) {
      // Update existing
      state = currentSession.copyWith(
        status: json['status'] != null
            ? GameStatus.values.firstWhere((e) => e.name == json['status'])
            : currentSession.status,
        languageCode: json['language_code'] ?? currentSession.languageCode,
        targetLanguageCode:
            json['target_language_code'] ?? currentSession.targetLanguageCode,
        currentQuestionIndex:
            json['current_question_index'] ??
            currentSession.currentQuestionIndex,
        participants: participants ?? currentSession.participants,
        chatMessages: messages ?? currentSession.chatMessages,
        theme: json['theme'] ?? currentSession.theme,
        totalQuestions: json['question_count'] ?? currentSession.totalQuestions,
        timePerQuestion:
            json['time_per_question'] ?? currentSession.timePerQuestion,
        currentQuestionStartAt: json['current_question_start_at'] != null
            ? DateTime.parse(json['current_question_start_at'])
            : currentSession.currentQuestionStartAt,
        questionIds: json['question_ids'] != null
            ? List<String>.from(json['question_ids'])
            : currentSession.questionIds,
        isPrivate: json['is_private'] ?? currentSession.isPrivate,
        isDuel: json['is_duel'] ?? currentSession.isDuel,
      );
    }
  }

  // --- Real-time Gameplay ---

  Future<void> submitAnswer(
    int questionIndex,
    int answerIndex,
    bool isCorrect,
  ) async {
    if (state == null) return;
    final user = AuthService().currentUser;
    if (user == null) return;

    // Calculate score increment and streak
    final currentPlayer = state!.participants.firstWhere(
      (p) => p.id == user.id,
    );
    final newScore = isCorrect
        ? currentPlayer.score + 100
        : currentPlayer.score;
    final newStreak = isCorrect ? currentPlayer.streak + 1 : 0;

    // Survival Mode Elimination
    final newRole = (state!.isSurvival && !isCorrect)
        ? 'spectator'
        : currentPlayer.role.name;

    final List<String> updatedMissedIds = List<String>.from(
      currentPlayer.missedConceptIds,
    );
    if (!isCorrect) {
      final currentQuestionConceptId =
          state!.questionIds[state!.currentQuestionIndex];
      if (!updatedMissedIds.contains(currentQuestionConceptId)) {
        updatedMissedIds.add(currentQuestionConceptId);
      }
    }

    await SupabaseConfig.client
        .from('live_participants')
        .update({
          'score': newScore,
          'streak': newStreak,
          'last_answer_status': isCorrect ? 'correct' : 'incorrect',
          'role': newRole,
          'missed_concept_ids': updatedMissedIds,
        })
        .eq('session_id', state!.id)
        .eq('user_id', user.id);
  }

  Future<void> nextQuestion() async {
    if (state == null) return;
    final nextIndex = state!.currentQuestionIndex + 1;

    if (nextIndex >= state!.totalQuestions) {
      await SupabaseConfig.client
          .from('live_sessions')
          .update({'status': 'finished'})
          .eq('id', state!.id);
    } else {
      // Survival Mode timing reduction (shrink by 10% each round, min 5s)
      int nextTime = state!.timePerQuestion;
      if (state!.isSurvival) {
        nextTime = (state!.timePerQuestion * 0.9).round();
        if (nextTime < 5) nextTime = 5;
      }

      // Sync restart timer for everyone
      await SupabaseConfig.client
          .from('live_sessions')
          .update({
            'current_question_index': nextIndex,
            'current_question_start_at': DateTime.now()
                .toUtc()
                .toIso8601String(),
            'time_per_question': nextTime,
          })
          .eq('id', state!.id);

      await SupabaseConfig.client
          .from('live_participants')
          .update({'last_answer_status': 'idle'})
          .eq('session_id', state!.id);
    }
  }

  Future<void> resetSession() async {
    if (state == null) return;

    // Reset all participants
    await SupabaseConfig.client
        .from('live_participants')
        .update({'score': 0, 'streak': 0, 'last_answer_status': 'idle'})
        .eq('session_id', state!.id);

    // Reset session
    await SupabaseConfig.client
        .from('live_sessions')
        .update({'status': 'lobby', 'current_question_index': 0})
        .eq('id', state!.id);
  }

  // --- Actions ---

  Future<void> requestToPlay() async {
    if (state == null) return;
    final userId = AuthService().userId;
    if (userId == null) return;

    await SupabaseConfig.client
        .from('live_participants')
        .update({'role': 'requesting'})
        .eq('session_id', state!.id)
        .eq('user_id', userId);
  }

  Future<void> acceptParticipant(String playerId) async {
    if (state == null) return;
    await SupabaseConfig.client
        .from('live_participants')
        .update({'role': 'player'})
        .eq('session_id', state!.id)
        .eq('user_id', playerId);
  }

  Future<void> rejectParticipant(String playerId) async {
    if (state == null) return;
    await SupabaseConfig.client
        .from('live_participants')
        .update({'role': 'spectator'})
        .eq('session_id', state!.id)
        .eq('user_id', playerId);
  }

  Future<void> updateSettings(Map<String, dynamic> settings) async {
    if (state == null) return;
    await SupabaseConfig.client
        .from('live_sessions')
        .update(settings)
        .eq('id', state!.id);
  }

  Future<void> startGame() async {
    if (state == null) return;

    // 1. Fetch real questions from vocabulary table based on theme
    final questions = await _generateSessionQuestions();

    // 2. Start countdown for everyone
    await SupabaseConfig.client
        .from('live_sessions')
        .update({'status': 'starting', 'question_ids': questions})
        .eq('id', state!.id);
  }

  Future<List<String>> _generateSessionQuestions() async {
    if (state == null) return [];

    final bool isMixedTheme = state!.theme == 'All' || state!.theme.isEmpty;
    final bool isMixedSubTheme =
        state!.subtheme == 'All' || state!.subtheme.isEmpty;

    // Build query based on theme/subtheme selection
    var query = SupabaseConfig.client
        .from('vocabulary')
        .select('concept_id')
        .eq('lang_code', state!.targetLanguageCode);

    if (!isMixedTheme) {
      query = query.eq('domain', state!.theme.toLowerCase());
    }

    if (!isMixedSubTheme) {
      query = query.eq('sub_domain', state!.subtheme.toLowerCase());
    }

    final response = await query.limit(state!.totalQuestions);

    final ids = (response as List)
        .map((r) => r['concept_id'].toString())
        .toList();

    // Fallback if results are insufficient
    if (ids.length < 5) {
      final globalResp = await SupabaseConfig.client
          .from('vocabulary')
          .select('concept_id')
          .eq('lang_code', state!.targetLanguageCode)
          .limit(state!.totalQuestions);
      return (globalResp as List)
          .map((r) => r['concept_id'].toString())
          .toList();
    }

    return ids;
  }

  Future<void> beginPlaying() async {
    if (state == null) return;
    await SupabaseConfig.client
        .from('live_sessions')
        .update({
          'status': 'playing',
          'current_question_start_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', state!.id);
  }

  Future<void> sendChatMessage(String text) async {
    if (state == null) return;
    final user = AuthService().currentUser;
    if (user == null) return;

    await SupabaseConfig.client.from('live_messages').insert({
      'session_id': state!.id,
      'sender_id': user.id,
      'sender_name': user.userMetadata?['display_name'] ?? 'User',
      'message': text,
    });
  }

  Future<void> sendReaction(String emoji) async {
    if (_channel == null) return;
    await _channel!.sendBroadcastMessage(
      event: 'reaction',
      payload: {'emoji': emoji, 'sender_id': AuthService().userId},
    );
  }

  Future<void> sendPulse(String type) async {
    if (_channel == null) return;
    await _channel!.sendBroadcastMessage(
      event: 'pulse',
      payload: {'type': type, 'sender_id': AuthService().userId},
    );
  }

  Future<void> resetToLobby() async {
    if (state == null) return;

    // Batch reset participants score
    await SupabaseConfig.client
        .from('live_participants')
        .update({'score': 0, 'last_answer_status': 'idle'})
        .eq('session_id', state!.id);

    // Update session status
    await SupabaseConfig.client
        .from('live_sessions')
        .update({'status': 'lobby', 'current_question_index': 0})
        .eq('id', state!.id);
  }

  Future<void> endGameForAll() async {
    if (state == null) return;
    await SupabaseConfig.client
        .from('live_sessions')
        .update({'status': 'terminated'})
        .eq('id', state!.id);
    _cleanup();
    state = null;
  }

  Future<void> leaveGame() async {
    if (state == null) return;
    final userId = AuthService().userId;
    if (userId == null) return;

    // Determine if the current user is the host
    final isHost = state!.hostId == userId;

    if (isHost) {
      // If host leaves without using passHostAndLeave, terminate session
      // suddenly to prevent "ghost" non-host sessions.
      await SupabaseConfig.client
          .from('live_sessions')
          .update({'status': 'terminated'})
          .eq('id', state!.id);
    }

    await SupabaseConfig.client
        .from('live_participants')
        .delete()
        .eq('session_id', state!.id)
        .eq('user_id', userId);

    _cleanup();
    state = null;
  }

  Future<void> passHostAndLeave(String newHostUserId) async {
    if (state == null) return;

    // 1. Update session table
    await SupabaseConfig.client
        .from('live_sessions')
        .update({'host_id': newHostUserId})
        .eq('id', state!.id);

    // 2. Update new host's role
    await SupabaseConfig.client
        .from('live_participants')
        .update({'role': 'host'})
        .eq('session_id', state!.id)
        .eq('user_id', newHostUserId);

    // 3. Current host leaves
    await leaveGame();
  }
}

final activeSessionProvider =
    StateNotifierProvider<ActiveGameNotifier, LiveGameSession?>((ref) {
      return ActiveGameNotifier(ref);
    });
