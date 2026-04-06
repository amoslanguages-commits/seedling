enum LiveGameType {
  vocabulary, // Multiple choice word matching
  sentences, // Fill-in-the-blank (cloze)
}

enum GameStatus {
  lobby, // Host is gathering players, users can join as spectators and request to play
  starting, // 3... 2... 1... countdown
  playing, // The live quiz is active
  finished, // Results and podium
  terminated, // Host ended the game
}

enum PlayerRole {
  host, // The creator of the room
  player, // Accepted to compete (up to 5)
  spectator, // Just watching, can request to become a player
  requesting, // Spectator asking to join
}

enum AnswerStatus {
  idle, // Has not answered yet
  answered, // Picked an option (show checkmark but keeping answer hidden)
  correct, // Once times up, show green
  incorrect, // Once times up, show red
}

class LivePlayer {
  final String id;
  final String displayName;
  final String avatarEmoji;
  final PlayerRole role;

  // Game State
  int score;
  int streak;
  final AnswerStatus lastAnswerStatus;
  final bool hasRequestedToPlay;

  // Botanical Rank Metadata
  final int level;
  final List<String> missedConceptIds;

  LivePlayer({
    required this.id,
    required this.displayName,
    required this.avatarEmoji,
    required this.role,
    this.score = 0,
    this.streak = 0,
    this.lastAnswerStatus = AnswerStatus.idle,
    this.hasRequestedToPlay = false,
    this.level = 1,
    this.missedConceptIds = const [],
  });

  String get botanicalRank {
    if (level >= 15) return 'Great Bloom';
    if (level >= 10) return 'Oak';
    if (level >= 6) return 'Seedling';
    if (level >= 3) return 'Sapling';
    return 'Sprout';
  }

  String get rankEmoji {
    if (level >= 15) return '🌸';
    if (level >= 10) return '🌳';
    if (level >= 6) return '🌲';
    if (level >= 3) return '🌿';
    return '🌱';
  }

  factory LivePlayer.fromJson(Map<String, dynamic> json) {
    return LivePlayer(
      id: json['user_id'] ?? '',
      displayName: json['display_name'] ?? 'Player',
      avatarEmoji: json['avatar_emoji'] ?? '👤',
      role: PlayerRole.values.firstWhere(
        (e) => e.name == (json['role'] ?? 'spectator'),
      ),
      score: json['score'] ?? 0,
      lastAnswerStatus: AnswerStatus.values.firstWhere(
        (e) => e.name == (json['last_answer_status'] ?? 'idle'),
      ),
      hasRequestedToPlay: json['role'] == 'requesting',
      level: json['level'] ?? 1,
      missedConceptIds: List<String>.from(json['missed_concept_ids'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': id,
      'display_name': displayName,
      'avatar_emoji': avatarEmoji,
      'role': role.name,
      'score': score,
      'last_answer_status': lastAnswerStatus.name,
      'level': level,
      'missed_concept_ids': missedConceptIds,
    };
  }

  LivePlayer copyWith({
    PlayerRole? role,
    int? score,
    int? streak,
    AnswerStatus? lastAnswerStatus,
    int? level,
    List<String>? missedConceptIds,
  }) {
    return LivePlayer(
      id: id,
      displayName: displayName,
      avatarEmoji: avatarEmoji,
      role: role ?? this.role,
      score: score ?? this.score,
      streak: streak ?? this.streak,
      lastAnswerStatus: lastAnswerStatus ?? this.lastAnswerStatus,
      level: level ?? this.level,
      missedConceptIds: missedConceptIds ?? this.missedConceptIds,
    );
  }
}

class LiveQuestion {
  final String questionText;
  final List<String> options;
  final int correctIndex;

  LiveQuestion({
    required this.questionText,
    required this.options,
    required this.correctIndex,
  });

  factory LiveQuestion.fromJson(Map<String, dynamic> json) {
    return LiveQuestion(
      questionText: json['text'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctIndex: json['correct_index'] ?? 0,
    );
  }
}

class LiveChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String message;
  final DateTime timestamp;

  LiveChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.timestamp,
  });

  factory LiveChatMessage.fromJson(Map<String, dynamic> json) {
    return LiveChatMessage(
      id: json['id'] ?? '',
      senderId: json['sender_id'] ?? '',
      senderName: json['sender_name'] ?? 'Unknown',
      message: json['message'] ?? '',
      timestamp: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

class LiveGameSession {
  final String id;
  final String hostId;
  final String hostName;
  final String title;

  // Configuration
  final LiveGameType gameType;
  final String theme;
  final String subtheme;
  final int totalQuestions;
  final int timePerQuestion;
  final int maxPlayers;

  final String languageCode;
  final String targetLanguageCode;

  final bool isPrivate;
  final bool isDuel;
  final int hostLevel;
  final String hostAvatarEmoji;
  final bool isSurvival;

  // State
  GameStatus status;
  int currentQuestionIndex;
  List<LivePlayer> participants;
  List<LiveQuestion> questions;
  List<LiveChatMessage> chatMessages;

  // Real-time synchronization
  final DateTime? currentQuestionStartAt;
  final List<String> questionIds;

  String get joinCode => id.substring(0, 6).toUpperCase();

  LiveGameSession({
    required this.id,
    required this.hostId,
    required this.hostName,
    required this.title,
    required this.gameType,
    required this.theme,
    required this.subtheme,
    required this.totalQuestions,
    required this.timePerQuestion,
    this.maxPlayers = 5,
    this.status = GameStatus.lobby,
    this.languageCode = 'en',
    this.targetLanguageCode = 'es',
    this.currentQuestionIndex = 0,
    this.isPrivate = false,
    this.isDuel = false,

    this.participants = const [],
    this.questions = const [],
    this.chatMessages = const [],
    this.currentQuestionStartAt,
    this.questionIds = const [],
    this.isSurvival = false,
    this.hostLevel = 1,
    this.hostAvatarEmoji = '👤',
  });

  String get hostBotanicalRank {
    if (hostLevel >= 15) return 'Great Bloom';
    if (hostLevel >= 10) return 'Oak';
    if (hostLevel >= 6) return 'Seedling';
    if (hostLevel >= 3) return 'Sapling';
    return 'Sprout';
  }

  String get hostRankEmoji {
    if (hostLevel >= 15) return '🌸';
    if (hostLevel >= 10) return '🌳';
    if (hostLevel >= 6) return '🌲';
    if (hostLevel >= 3) return '🌿';
    return '🌱';
  }

  factory LiveGameSession.fromJson(
    Map<String, dynamic> json, {
    List<LivePlayer> participants = const [],
    List<LiveChatMessage> messages = const [],
  }) {
    return LiveGameSession(
      id: json['id'],
      hostId: json['host_id'],
      hostName:
          json['host_name'] ??
          'Host', // Will be enriched from profiles join or stored
      title: json['title'] ?? 'Live Arena',
      gameType: LiveGameType.values.firstWhere(
        (e) => e.name == json['game_type'],
        orElse: () => LiveGameType.vocabulary,
      ),
      theme: json['theme'] ?? 'General',
      subtheme: json['subtheme'] ?? '',
      totalQuestions: json['question_count'] ?? 10,
      timePerQuestion: json['time_per_question'] ?? 15,
      maxPlayers: json['max_players'] ?? 5,
      status: GameStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => GameStatus.lobby,
      ),
      languageCode: json['language_code'] ?? 'en',
      targetLanguageCode: json['target_language_code'] ?? 'es',
      currentQuestionIndex: json['current_question_index'] ?? 0,
      isPrivate: json['is_private'] ?? false,
      isDuel: json['is_duel'] ?? false,
      participants: participants,
      chatMessages: messages,
      currentQuestionStartAt: json['current_question_start_at'] != null
          ? DateTime.parse(json['current_question_start_at'])
          : null,
      questionIds: List<String>.from(json['question_ids'] ?? []),
      isSurvival: json['is_survival'] ?? false,
      hostLevel: json['host_level'] ?? 1,
      hostAvatarEmoji: json['host_avatar_emoji'] ?? '👤',
    );
  }

  // Helpers
  List<LivePlayer> get activePlayers => participants
      .where((p) => p.role == PlayerRole.player || p.role == PlayerRole.host)
      .toList();

  List<LivePlayer> get spectators => participants
      .where(
        (p) =>
            p.role == PlayerRole.spectator || p.role == PlayerRole.requesting,
      )
      .toList();

  List<LivePlayer> get pendingRequests =>
      participants.where((p) => p.role == PlayerRole.requesting).toList();

  int get playerCount => activePlayers.length;
  bool get isFull => playerCount >= maxPlayers;

  LiveGameSession copyWith({
    String? title,
    LiveGameType? gameType,
    String? theme,
    String? subtheme,

    int? totalQuestions,
    int? timePerQuestion,
    int? maxPlayers,
    GameStatus? status,
    String? languageCode,
    String? targetLanguageCode,
    int? currentQuestionIndex,

    List<LivePlayer>? participants,
    List<LiveQuestion>? questions,
    List<LiveChatMessage>? chatMessages,
    DateTime? currentQuestionStartAt,
    List<String>? questionIds,
    bool? isPrivate,
    bool? isDuel,
    bool? isSurvival,
    int? hostLevel,
    String? hostAvatarEmoji,
  }) {
    return LiveGameSession(
      id: id,
      hostId: hostId,
      hostName: hostName,
      title: title ?? this.title,
      gameType: gameType ?? this.gameType,
      theme: theme ?? this.theme,
      subtheme: subtheme ?? this.subtheme,

      totalQuestions: totalQuestions ?? this.totalQuestions,
      timePerQuestion: timePerQuestion ?? this.timePerQuestion,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      status: status ?? this.status,
      languageCode: languageCode ?? this.languageCode,
      targetLanguageCode: targetLanguageCode ?? this.targetLanguageCode,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      participants: participants ?? this.participants,
      questions: questions ?? this.questions,
      chatMessages: chatMessages ?? this.chatMessages,
      currentQuestionStartAt:
          currentQuestionStartAt ?? this.currentQuestionStartAt,
      questionIds: questionIds ?? this.questionIds,
      isPrivate: isPrivate ?? this.isPrivate,
      isDuel: isDuel ?? this.isDuel,
      isSurvival: isSurvival ?? this.isSurvival,
      hostLevel: hostLevel ?? this.hostLevel,
      hostAvatarEmoji: hostAvatarEmoji ?? this.hostAvatarEmoji,
    );
  }
}
