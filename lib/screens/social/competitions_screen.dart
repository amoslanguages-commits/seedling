import 'package:flutter/material.dart';
import '../../core/page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors.dart';
import '../../core/typography.dart';
import '../../models/social.dart';
import '../../providers/app_providers.dart';
import 'competition_detail_screen.dart';
import 'friends_screen.dart';

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
        title: const Text('Competitions', style: SeedlingTypography.heading2),
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
        child: competitionsAsync.when(
          data: (competitions) {
            final active = competitions.where((c) => c.status == CompetitionStatus.active).toList();
            final upcoming = competitions.where((c) => c.status == CompetitionStatus.upcoming).toList();
            
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Active Competitions
                if (active.isNotEmpty) ...[
                  const Text(
                    'Active Now',
                    style: SeedlingTypography.heading3,
                  ),
                  const SizedBox(height: 15),
                  ...active.map((comp) => _buildCompetitionCard(context, comp)),
                  const SizedBox(height: 30),
                ],
                
                // Upcoming Competitions
                if (upcoming.isNotEmpty) ...[
                  const Text(
                    'Coming Soon',
                    style: SeedlingTypography.heading3,
                  ),
                  const SizedBox(height: 15),
                  ...upcoming.map((comp) => _buildUpcomingCard(comp)),
                ],

                if (active.isEmpty && upcoming.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text('No competitions available right now.'),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error loading competitions: $e')),
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
          gradient: const LinearGradient(
            colors: [
              SeedlingColors.seedlingGreen,
              SeedlingColors.deepRoot,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
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
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${comp.daysRemaining} days left',
                      style: SeedlingTypography.caption.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: SeedlingColors.sunlight,
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
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                comp.description,
                style: SeedlingTypography.body.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 20),
              
              // Mini Leaderboard Preview
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
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
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              p.isCurrentUser ? 'You' : p.displayName,
                              style: SeedlingTypography.body.copyWith(
                                color: Colors.white,
                                fontWeight: p.isCurrentUser 
                                    ? FontWeight.w600 
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          Text(
                            '${p.score}',
                            style: SeedlingTypography.body.copyWith(
                              color: Colors.white,
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
          color: SeedlingColors.morningDew.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SeedlingColors.morningDew.withValues(alpha: 0.3),
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
              color: SeedlingColors.sunlight.withValues(alpha: 0.3),
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
