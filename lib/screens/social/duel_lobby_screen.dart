import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors.dart';
import '../../core/typography.dart';
import '../../models/social.dart';
import '../../providers/app_providers.dart';
import 'live_duel_screen.dart';

class DuelLobbyScreen extends ConsumerStatefulWidget {
  const DuelLobbyScreen({super.key});

  @override
  ConsumerState<DuelLobbyScreen> createState() => _DuelLobbyScreenState();
}

class _DuelLobbyScreenState extends ConsumerState<DuelLobbyScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<Friend> _searchResults = [];
  bool _isSearching = false;
  
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 800)
    )..forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    
    final results = await ref.read(socialServiceProvider).searchUsers(query);
    
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }
  
  void _startDuel(Friend opponent) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LiveDuelScreen(opponent: opponent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(friendsProvider);
    
    return Scaffold(
      backgroundColor: SeedlingColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('The Arena', style: SeedlingTypography.heading2),
        iconTheme: const IconThemeData(color: SeedlingColors.textPrimary),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [SeedlingColors.deepRoot, SeedlingColors.seedlingGreen],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: SeedlingColors.seedlingGreen.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Live Duel",
                                style: SeedlingTypography.heading2.copyWith(color: Colors.white),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "Challenge a friend or rival.\nWinner takes the Sunlight pot!",
                                style: SeedlingTypography.body.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, color: SeedlingColors.sunlight, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "50 XP",
                                style: SeedlingTypography.heading3.copyWith(color: SeedlingColors.sunlight),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  Text('Find Opponent', style: SeedlingTypography.heading3),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (_searchController.text == val && mounted) {
                          _performSearch(val);
                        }
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Enter username...',
                      prefixIcon: const Icon(Icons.search, color: SeedlingColors.waterBlue),
                      filled: true,
                      fillColor: SeedlingColors.cardBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: SeedlingColors.waterBlue, width: 2),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Expanded(
                    child: _searchController.text.isNotEmpty
                      ? _buildSearchResults()
                      : _buildFriendsList(friendsAsync),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator(color: SeedlingColors.waterBlue));
    }
    
    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'No users found matching "${_searchController.text}"',
          style: SeedlingTypography.body.copyWith(color: SeedlingColors.textSecondary),
        ),
      );
    }
    
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return _OpponentCard(
          friend: user,
          onTap: () => _startDuel(user),
        );
      },
    );
  }
  
  Widget _buildFriendsList(AsyncValue<List<Friend>> friendsAsync) {
    return friendsAsync.when(
      data: (friends) {
        if (friends.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people_alt_outlined, size: 60, color: SeedlingColors.morningDew),
                const SizedBox(height: 15),
                Text(
                  'Search for a username above\nto start a duel!',
                  textAlign: TextAlign.center,
                  style: SeedlingTypography.body.copyWith(color: SeedlingColors.textSecondary),
                ),
              ],
            ),
          );
        }
        
        final sortedFriends = List<Friend>.from(friends)
          ..sort((a, b) {
            if (a.isOnline && !b.isOnline) return -1;
            if (!a.isOnline && b.isOnline) return 1;
            return a.displayName.compareTo(b.displayName);
          });
          
        return FadeTransition(
          opacity: _fadeController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Available Friends', style: SeedlingTypography.body.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: sortedFriends.length,
                  itemBuilder: (context, index) {
                    return _OpponentCard(
                      friend: sortedFriends[index],
                      onTap: () => _startDuel(sortedFriends[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: SeedlingColors.waterBlue)),
      error: (_, __) => const Center(child: Text('Could not load friends')),
    );
  }
}

class _OpponentCard extends StatelessWidget {
  final Friend friend;
  final VoidCallback onTap;
  
  const _OpponentCard({
    required this.friend,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: SeedlingColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: friend.isOnline ? SeedlingColors.success.withOpacity(0.5) : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: SeedlingColors.morningDew,
                      backgroundImage: friend.avatarUrl != null ? NetworkImage(friend.avatarUrl!) : null,
                      child: friend.avatarUrl == null
                          ? Text(
                              friend.displayName[0].toUpperCase(),
                              style: SeedlingTypography.heading3.copyWith(color: SeedlingColors.seedlingGreen),
                            )
                          : null,
                    ),
                    if (friend.isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: SeedlingColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: SeedlingColors.cardBackground, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend.displayName,
                        style: SeedlingTypography.body.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.local_fire_department, size: 14, color: SeedlingColors.sunlight),
                          const SizedBox(width: 4),
                          Text('${friend.currentStreak} Streak', style: SeedlingTypography.caption),
                          const SizedBox(width: 10),
                          const Icon(Icons.star, size: 14, color: SeedlingColors.seedlingGreen),
                          const SizedBox(width: 4),
                          Text('${friend.totalXP} XP', style: SeedlingTypography.caption),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: SeedlingColors.waterBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'CHALLENGE',
                    style: SeedlingTypography.caption.copyWith(
                      color: SeedlingColors.waterBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
