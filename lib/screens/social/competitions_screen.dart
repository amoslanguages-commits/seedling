import 'package:flutter/material.dart';
import '../../core/page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors.dart';
import '../../core/typography.dart';
import '../../models/social.dart';
import '../../providers/app_providers.dart';
import 'competition_detail_screen.dart';
import 'friends_screen.dart';
import 'duel_lobby_screen.dart';
import 'forest_rankings_screen.dart';

class CompetitionsScreen extends ConsumerWidget {
  const CompetitionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final competitionsAsync = ref.watch(competitionsProvider);
    
    return Scaffold(
      backgroundColor: SeedlingColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Growth Arena', style: SeedlingTypography.heading2),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_outlined, color: SeedlingColors.deepRoot),
            onPressed: () {
              Navigator.push(
                context,
                SeedlingPageRoute(page: const FriendsScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(competitionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // --- NEW: Live Duel Arena Banner ---
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DuelLobbyScreen()),
                );
              },
              child: Container(
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
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'LIVE',
                              style: SeedlingTypography.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Sunlight Stakes',
                            style: SeedlingTypography.heading2.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Challenge friends to a 60s duel.',
                            style: SeedlingTypography.body.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.electric_bolt_rounded,
                      color: SeedlingColors.sunlight,
                      size: 40,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // --- NEW: Forest Rankings Banner ---
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ForestRankingsScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: SeedlingColors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: SeedlingColors.morningDew.withOpacity(0.5), width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: SeedlingColors.sunlight.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.star_rounded, color: SeedlingColors.sunlight),
                        ),
                        const SizedBox(width: 15),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Forest Rankings', style: SeedlingTypography.heading3),
                            Text(
                              'See where you stand', 
                              style: SeedlingTypography.caption,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Icon(Icons.chevron_right_rounded, color: SeedlingColors.textSecondary),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // --- Rest of Competitions List ---
            Text('Seasonal Events', style: SeedlingTypography.heading3),
            const SizedBox(height: 15),

            competitionsAsync.when(
              data: (competitions) {
                final active = competitions.where((c) => c.status == CompetitionStatus.active).toList();
                final upcoming = competitions.where((c) => c.status == CompetitionStatus.upcoming).toList();
                
                if (active.isEmpty && upcoming.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'No seasonal events right now.',
                        style: SeedlingTypography.body.copyWith(color: SeedlingColors.textSecondary),
                      ),
                    ),
                  );
                }
                
                return Column(
                  children: [
                    ...active.map((comp) => _buildCompetitionCard(context, comp)),
                    const SizedBox(height: 15),
                    ...upcoming.map((comp) => _buildUpcomingCard(comp)),
                  ],
                );
              },
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: SeedlingColors.seedlingGreen),
              )),
              error: (e, _) => Center(child: Text('Error loading events: $e')),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCompetitionCard(BuildContext context, Competition comp) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CompetitionDetailScreen(competition: comp),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: SeedlingColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: SeedlingColors.seedlingGreen.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: SeedlingColors.seedlingGreen.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ]
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: SeedlingColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${comp.daysRemaining} days left',
                      style: SeedlingTypography.caption.copyWith(
                        color: SeedlingColors.warning,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: SeedlingColors.sunlight.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '🏆',
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                comp.title,
                style: SeedlingTypography.heading2.copyWith(
                  color: SeedlingColors.textPrimary,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                comp.description,
                style: SeedlingTypography.body.copyWith(
                  color: SeedlingColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              
              // Mini Leaderboard Preview
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: SeedlingColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SeedlingColors.morningDew.withOpacity(0.2)),
                ),
                child: Column(
                  children: comp.participants.take(3).map((p) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Text(
                            '#${p.rank}',
                            style: SeedlingTypography.caption.copyWith(
                              color: SeedlingColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              p.isCurrentUser ? 'You' : p.displayName,
                              style: SeedlingTypography.body.copyWith(
                                color: SeedlingColors.textPrimary,
                                fontWeight: p.isCurrentUser 
                                    ? FontWeight.w600 
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          Text(
                            '${p.score}',
                            style: SeedlingTypography.body.copyWith(
                              color: SeedlingColors.seedlingGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              
              const SizedBox(height: 15),
              
              // Prize
              Row(
                children: [
                  const Icon(
                    Icons.star,
                    color: SeedlingColors.sunlight,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${comp.prizeXP} XP Prize',
                    style: SeedlingTypography.body.copyWith(
                      color: SeedlingColors.sunlight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildUpcomingCard(Competition comp) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SeedlingColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: SeedlingColors.morningDew.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SeedlingColors.morningDew.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_today,
              color: SeedlingColors.textSecondary,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comp.title,
                  style: SeedlingTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Starts in ${comp.startDate.difference(DateTime.now()).inDays} days',
                  style: SeedlingTypography.caption,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: SeedlingColors.sunlight.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${comp.prizeXP} XP',
              style: SeedlingTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
