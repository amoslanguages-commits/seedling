import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors.dart';
import '../../core/typography.dart';
import '../../models/social.dart';
import '../../providers/app_providers.dart';
import 'duel_lobby_screen.dart';

class ForestRankingsScreen extends ConsumerWidget {
  const ForestRankingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsProvider);

    return Scaffold(
      backgroundColor: SeedlingColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Forest Rankings', style: SeedlingTypography.heading2),
        iconTheme: const IconThemeData(color: SeedlingColors.textPrimary),
      ),
      body: friendsAsync.when(
        data: (friends) {
          if (friends.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Add some friends to see where you stand in the forest!',
                  style: SeedlingTypography.body,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // Sort by XP descending to build leaderboard
          final sortedFriends = List<Friend>.from(friends)
            ..sort((a, b) => b.totalXP.compareTo(a.totalXP));

          return Stack(
            children: [
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100), // padding for bottom card
                itemCount: sortedFriends.length,
                itemBuilder: (context, index) {
                  final friend = sortedFriends[index];
                  return _buildRankingCard(context, friend, index + 1);
                },
              ),
              
              // "You are here" pinned card
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: SeedlingColors.cardBackground,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: SeedlingColors.seedlingGreen,
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'You',
                              style: SeedlingTypography.body.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Keep learning to climb the ranks!',
                              style: SeedlingTypography.caption,
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const DuelLobbyScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SeedlingColors.sunlight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          'Duel',
                          style: SeedlingTypography.body.copyWith(
                            color: SeedlingColors.deepRoot,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: SeedlingColors.seedlingGreen)),
        error: (_, __) => const Center(child: Text('Failed to load rankings')),
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
        border: rank <= 3 ? Border.all(color: rankColor.withOpacity(0.5), width: 2) : Border.all(color: Colors.transparent),
        boxShadow: rank <= 3 ? [
          BoxShadow(
            color: rankColor.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ] : null,
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
            backgroundImage: friend.avatarUrl != null ? NetworkImage(friend.avatarUrl!) : null,
            child: friend.avatarUrl == null
                ? Text(
                    friend.displayName[0].toUpperCase(),
                    style: SeedlingTypography.heading3.copyWith(color: SeedlingColors.seedlingGreen),
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
                  style: SeedlingTypography.body.copyWith(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: SeedlingColors.sunlight),
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
