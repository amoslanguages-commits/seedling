// ================ SOCIAL MODELS ================

enum FriendshipStatus { pending, accepted, blocked, none }

class Friend {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int currentStreak;
  final int totalXP;
  final bool isOnline;
  final DateTime? lastActive;
  final FriendshipStatus status;

  Friend({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.currentStreak,
    required this.totalXP,
    this.isOnline = false,
    this.lastActive,
    this.status = FriendshipStatus.accepted,
  });

  factory Friend.fromMap(
    Map<String, dynamic> map, {
    FriendshipStatus? statusOverride,
  }) {
    return Friend(
      userId: map['id'] ?? map['user_id'] ?? '',
      displayName: map['display_name'] ?? 'Anonymous',
      avatarUrl: map['avatar_url'],
      currentStreak:
          map['user_stats']?[0]?['current_streak'] ??
          map['current_streak'] ??
          0,
      totalXP: map['user_stats']?[0]?['total_xp'] ?? map['total_xp'] ?? 0,
      isOnline: map['is_online'] ?? false,
      lastActive: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : null,
      status: statusOverride ?? FriendshipStatus.accepted,
    );
  }
}

// ================ COMPETITION MODELS ================

enum CompetitionType {
  mostWords, // Most words learned
  longestStreak, // Longest streak maintained
  perfectAccuracy, // Highest accuracy percentage
  mostTime, // Most time spent learning
}

enum CompetitionStatus { upcoming, active, completed }

class CompetitionParticipant {
  final String userId;
  final String displayName;
  final int score;
  final int rank;
  final bool isCurrentUser;

  CompetitionParticipant({
    required this.userId,
    required this.displayName,
    required this.score,
    required this.rank,
    this.isCurrentUser = false,
  });

  factory CompetitionParticipant.fromMap(
    Map<String, dynamic> map,
    String currentUserId,
  ) {
    return CompetitionParticipant(
      userId: map['user_id'],
      displayName: map['profiles']?['display_name'] ?? 'Anonymous',
      score: map['score'] ?? 0,
      rank: map['rank'],
      isCurrentUser: map['user_id'] == currentUserId,
    );
  }
}

class Competition {
  final String id;
  final String title;
  final String description;
  final CompetitionType type;
  final DateTime startDate;
  final DateTime endDate;
  final int entryXP;
  final int prizeXP;
  final List<CompetitionParticipant> participants;
  final CompetitionStatus status;

  Competition({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.entryXP,
    required this.prizeXP,
    required this.participants,
    this.status = CompetitionStatus.upcoming,
  });

  factory Competition.fromMap(Map<String, dynamic> map, String currentUserId) {
    return Competition(
      id: map['id'],
      title: map['title'],
      description: map['description'] ?? '',
      type: _parseType(map['type']),
      startDate: DateTime.parse(map['start_date']),
      endDate: DateTime.parse(map['end_date']),
      entryXP: map['entry_xp'] ?? 0,
      prizeXP: map['prize_xp'] ?? 0,
      status: _parseStatus(map['status']),
      participants: (map['competition_participants'] as List? ?? [])
          .map((p) => CompetitionParticipant.fromMap(p, currentUserId))
          .toList(),
    );
  }

  static CompetitionType _parseType(String type) {
    switch (type) {
      case 'most_words':
        return CompetitionType.mostWords;
      case 'longest_streak':
        return CompetitionType.longestStreak;
      case 'perfect_accuracy':
        return CompetitionType.perfectAccuracy;
      case 'most_time':
        return CompetitionType.mostTime;
      default:
        return CompetitionType.mostWords;
    }
  }

  static CompetitionStatus _parseStatus(String status) {
    switch (status) {
      case 'upcoming':
        return CompetitionStatus.upcoming;
      case 'active':
        return CompetitionStatus.active;
      case 'completed':
        return CompetitionStatus.completed;
      default:
        return CompetitionStatus.upcoming;
    }
  }

  bool get isActive =>
      DateTime.now().isAfter(startDate) && DateTime.now().isBefore(endDate);

  int get daysRemaining => endDate.difference(DateTime.now()).inDays;
}
