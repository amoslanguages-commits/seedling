import '../core/supabase_config.dart';
import '../models/social.dart';
import 'auth_service.dart';

class SocialService {
  static final SocialService _instance = SocialService._internal();
  factory SocialService() => _instance;
  SocialService._internal();

  final _supabase = SupabaseConfig.client;
  final _auth = AuthService();

  String? get currentUserId => _auth.userId;

  // ================ FRIEND MANAGEMENT ================

  /// List all accepted friends with their stats
  Future<List<Friend>> getFriends() async {
    if (currentUserId == null) return [];

    // Query friendships where current user is sender or receiver and status is accepted
    final response = await _supabase
        .from('friendships')
        .select('''
          user_id,
          friend_id,
          status,
          sender:profiles!friendships_user_id_fkey(id, display_name, avatar_url, user_stats(total_xp, current_streak)),
          receiver:profiles!friendships_friend_id_fkey(id, display_name, avatar_url, user_stats(total_xp, current_streak))
        ''')
        .eq('status', 'accepted')
        .or('user_id.eq.$currentUserId,friend_id.eq.$currentUserId');

    return (response as List).map((data) {
      final bool isSender = data['user_id'] == currentUserId;
      final friendData = isSender ? data['receiver'] : data['sender'];
      return Friend.fromMap(
        friendData,
        statusOverride: FriendshipStatus.accepted,
      );
    }).toList();
  }

  /// List incoming friend requests
  Future<List<Friend>> getPendingRequests() async {
    if (currentUserId == null) return [];

    final response = await _supabase
        .from('friendships')
        .select('''
          id,
          user_id,
          sender:profiles!friendships_user_id_fkey(id, display_name, avatar_url, user_stats(total_xp, current_streak))
        ''')
        .eq('friend_id', currentUserId!)
        .eq('status', 'pending');

    return (response as List).map((data) {
      final senderData = data['sender'];
      return Friend.fromMap(
        senderData,
        statusOverride: FriendshipStatus.pending,
      );
    }).toList();
  }

  /// Search for users by display name or email
  Future<List<Friend>> searchUsers(String query) async {
    if (currentUserId == null || query.isEmpty) return [];

    final response = await _supabase
        .from('profiles')
        .select(
          'id, display_name, avatar_url, user_stats(total_xp, current_streak)',
        )
        .neq('id', currentUserId!)
        .or('display_name.ilike.%$query%,email.ilike.%$query%')
        .limit(10);

    return (response as List).map((data) => Friend.fromMap(data)).toList();
  }

  /// Send a friend request
  Future<void> sendFriendRequest(String targetUserId) async {
    if (currentUserId == null) return;

    await _supabase.from('friendships').insert({
      'user_id': currentUserId,
      'friend_id': targetUserId,
      'status': 'pending',
    });
  }

  /// Respond to a friend request
  Future<void> respondToRequest(String senderId, bool accept) async {
    if (currentUserId == null) return;

    if (accept) {
      await _supabase
          .from('friendships')
          .update({'status': 'accepted'})
          .eq('user_id', senderId)
          .eq('friend_id', currentUserId!);
    } else {
      await _supabase
          .from('friendships')
          .delete()
          .eq('user_id', senderId)
          .eq('friend_id', currentUserId!);
    }
  }

  // ================ COMPETITIONS ================

  /// Get active competitions for current user
  Future<List<Competition>> getCompetitions() async {
    if (currentUserId == null) return [];

    final response = await _supabase
        .from('competitions')
        .select('''
          *,
          competition_participants(
            user_id,
            score,
            rank,
            profiles(display_name, avatar_url)
          )
        ''')
        .order('end_date', ascending: true);

    return (response as List)
        .map((data) => Competition.fromMap(data, currentUserId!))
        .toList();
  }

  /// Join a competition
  Future<void> joinCompetition(String competitionId) async {
    if (currentUserId == null) return;

    await _supabase.from('competition_participants').insert({
      'competition_id': competitionId,
      'user_id': currentUserId,
      'score': 0,
    });
  }

  // ================ RANKINGS ================

  /// Get global rankings (top users by XP)
  Future<List<Friend>> getGlobalRankings({int limit = 50}) async {
    final response = await _supabase
        .from('user_stats')
        .select('''
          total_xp,
          current_streak,
          profiles(id, display_name, avatar_url)
        ''')
        .order('total_xp', ascending: false)
        .limit(limit);

    return (response as List).map<Friend>((data) {
      final profile = data['profiles'];
      return Friend(
        userId: profile['id'],
        displayName: profile['display_name'] ?? 'Unknown Explorer',
        avatarUrl: profile['avatar_url'],
        totalXP: data['total_xp'] ?? 0,
        currentStreak: data['current_streak'] ?? 0,
        status: FriendshipStatus.none, // Generic for global rankings
      );
    }).toList();
  }

  // ================ USER COMPETE STATS ================

  /// Get the current user's compete stats from Supabase user_stats
  Future<Map<String, dynamic>?> getUserCompeteStats() async {
    if (currentUserId == null) return null;

    final response = await _supabase
        .from('user_stats')
        .select(
          'total_xp, current_streak, total_words_learned, challenges_won, total_rooms_hosted, spectator_minutes',
        )
        .eq('user_id', currentUserId!)
        .maybeSingle();

    return response;
  }

  /// Get the current user's global rank position (1-indexed)
  Future<int> getGlobalRankPosition() async {
    if (currentUserId == null) return 0;

    // Count how many users have more XP than the current user
    final myStats = await getUserCompeteStats();
    final myXP = (myStats?['total_xp'] as int?) ?? 0;

    final response = await _supabase
        .from('user_stats')
        .select('user_id')
        .gt('total_xp', myXP);

    return ((response as List).length) + 1;
  }
}
