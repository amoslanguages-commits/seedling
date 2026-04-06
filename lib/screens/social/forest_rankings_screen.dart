import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors.dart';
import '../../core/typography.dart';
import '../../models/social.dart';
import '../../providers/app_providers.dart';

class ForestRankingsScreen extends ConsumerStatefulWidget {
  const ForestRankingsScreen({super.key});

  @override
  ConsumerState<ForestRankingsScreen> createState() =>
      _ForestRankingsScreenState();
}

class _ForestRankingsScreenState extends ConsumerState<ForestRankingsScreen> {
  bool _showGlobal = false;

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(friendsProvider);
    final globalAsync = ref.watch(globalRankingsProvider);
    final rankingsAsync = _showGlobal ? globalAsync : friendsAsync;

    return Scaffold(
      backgroundColor: SeedlingColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Forest Rankings', style: SeedlingTypography.heading2),
        iconTheme: const IconThemeData(color: SeedlingColors.textPrimary),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildRankingTabs(),
            const SizedBox(height: 24),
            Expanded(
              child: rankingsAsync.when(
                data: (friends) {
                  if (friends.isEmpty) {
                    return Center(
                      child: Text(
                        _showGlobal
                            ? 'No global rankings available yet.'
                            : 'Add some friends to see where you stand in the forest!',
                        style: SeedlingTypography.body,
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  // Sort by XP descending to build leaderboard
                  final sortedFriends = List<Friend>.from(friends)
                    ..sort((a, b) => b.totalXP.compareTo(a.totalXP));

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: sortedFriends.length,
                    itemBuilder: (context, index) {
                      final friend = sortedFriends[index];
                      return _buildRankingCard(context, friend, index + 1);
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: SeedlingColors.seedlingGreen,
                  ),
                ),
                error: (_, __) =>
                    const Center(child: Text('Failed to load rankings')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SeedlingColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTabButton('Friends', !_showGlobal)),
          Expanded(child: _buildTabButton('Global', _showGlobal)),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, bool active) {
    return GestureDetector(
      onTap: () => setState(() => _showGlobal = label == 'Global'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? SeedlingColors.seedlingGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: SeedlingTypography.body.copyWith(
              fontWeight: FontWeight.bold,
              color: active ? Colors.white : SeedlingColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRankingCard(BuildContext context, Friend friend, int rank) {
    Color rankColor;
    if (rank == 1) {
      rankColor = SeedlingColors.sunlight;
    } else if (rank == 2) {
      rankColor = SeedlingColors.morningDew;
    } else if (rank == 3) {
      rankColor = SeedlingColors.waterBlue;
    } else {
      rankColor = SeedlingColors.textSecondary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SeedlingColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: rank <= 3
            ? Border.all(color: rankColor.withValues(alpha: 0.5), width: 2)
            : Border.all(color: Colors.transparent),
        boxShadow: rank <= 3
            ? [
                BoxShadow(
                  color: rankColor.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '#$rank',
              style: SeedlingTypography.heading3.copyWith(color: rankColor),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 15),
          CircleAvatar(
            radius: 20,
            backgroundColor: SeedlingColors.morningDew,
            backgroundImage: friend.avatarUrl != null
                ? NetworkImage(friend.avatarUrl!)
                : null,
            child: friend.avatarUrl == null
                ? Text(
                    friend.displayName[0].toUpperCase(),
                    style: SeedlingTypography.heading3.copyWith(
                      color: SeedlingColors.seedlingGreen,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.displayName,
                  style: SeedlingTypography.body.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.star,
                      size: 14,
                      color: SeedlingColors.sunlight,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${friend.totalXP} XP',
                      style: SeedlingTypography.caption,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
