import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors.dart';
import '../../core/typography.dart';
import '../../models/social.dart';
import '../../widgets/cards.dart';
import '../../widgets/buttons.dart';
import '../../providers/app_providers.dart';

class CompetitionDetailScreen extends ConsumerWidget {
  final Competition competition;
  
  const CompetitionDetailScreen({
    super.key,
    required this.competition,
  });
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isParticipant = competition.participants.any(
      (p) => p.userId == ref.read(socialServiceProvider).currentUserId
    );

    return Scaffold(
      backgroundColor: SeedlingColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: SeedlingColors.seedlingGreen,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(competition.title),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      SeedlingColors.freshSprout,
                      SeedlingColors.seedlingGreen,
                    ],
                  ),
                ),
                child: const Center(
                  child: Text(
                    '🏆',
                    style: TextStyle(fontSize: 80),
                  ),
                ),
              ),
            ),
          ),
          
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Description
                Text(
                  competition.description,
                  style: SeedlingTypography.bodyLarge,
                ),
                
                const SizedBox(height: 20),
                
                // Time Remaining
                GrowingCard(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: SeedlingColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.timer,
                          color: SeedlingColors.error,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Time Remaining',
                              style: SeedlingTypography.caption,
                            ),
                            Text(
                              '${competition.daysRemaining} days',
                              style: SeedlingTypography.heading3.copyWith(
                                color: SeedlingColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Prize
                GrowingCard(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: SeedlingColors.sunlight.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.emoji_events,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Prize Pool',
                              style: SeedlingTypography.caption,
                            ),
                            Text(
                              '${competition.prizeXP} XP',
                              style: SeedlingTypography.heading3.copyWith(
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                if (competition.participants.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  const Text(
                    'Leaderboard',
                    style: SeedlingTypography.heading2,
                  ),
                  const SizedBox(height: 15),
                  ...competition.participants.map((p) => _buildLeaderboardRow(p)),
                ],
                
                const SizedBox(height: 30),
                
                // Join/Continue Button
                if (competition.isActive)
                  OrganicButton(
                    text: isParticipant ? 'Continue Competing' : 'Join Competition',
                    onPressed: () async {
                      if (!isParticipant) {
                        await ref.read(socialServiceProvider).joinCompetition(competition.id);
                        ref.invalidate(competitionsProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Joined competition!')),
                          );
                          Navigator.pop(context);
                        }
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    height: 60,
                  ),
                
                if (competition.status == CompetitionStatus.upcoming && !isParticipant)
                  OrganicButton(
                    text: 'Register Early',
                    onPressed: () async {
                      await ref.read(socialServiceProvider).joinCompetition(competition.id);
                      ref.invalidate(competitionsProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Registered successfully!')),
                        );
                        Navigator.pop(context);
                      }
                    },
                    height: 60,
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLeaderboardRow(CompetitionParticipant p) {
    Color rankColor = SeedlingColors.textSecondary;
    if (p.rank == 1) rankColor = const Color(0xFFFFD700);
    if (p.rank == 2) rankColor = const Color(0xFFC0C0C0);
    if (p.rank == 3) rankColor = const Color(0xFFCD7F32);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.isCurrentUser
            ? SeedlingColors.seedlingGreen.withValues(alpha: 0.1)
            : SeedlingColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: p.isCurrentUser
            ? Border.all(color: SeedlingColors.seedlingGreen)
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: rankColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: p.rank <= 3
                  ? Text(
                      ['🥇', '🥈', '🥉'][p.rank - 1],
                      style: const TextStyle(fontSize: 18),
                    )
                  : Text(
                      '#${p.rank}',
                      style: SeedlingTypography.caption.copyWith(
                        color: rankColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              p.isCurrentUser ? 'You' : p.displayName,
              style: SeedlingTypography.body.copyWith(
                fontWeight: p.isCurrentUser ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Text(
            '${p.score}',
            style: SeedlingTypography.heading3,
          ),
        ],
      ),
    );
  }
}
