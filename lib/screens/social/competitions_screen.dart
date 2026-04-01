import 'package:flutter/material.dart';
import '../../core/page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors.dart';
import '../../core/typography.dart';
import '../../models/multiplayer.dart';
import '../../providers/multiplayer_provider.dart';
import 'multiplayer/host_setup_screen.dart';
import 'multiplayer/multiplayer_lobby_screen.dart';

class CompetitionsScreen extends ConsumerWidget {
  const CompetitionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeGames = ref.watch(filteredGamesProvider);
    final activeFilter = ref.watch(gameFilterProvider);
    
    return Scaffold(
      backgroundColor: SeedlingColors.background,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: SeedlingColors.deepRoot,
        onPressed: () {
          Navigator.push(context, SeedlingPageRoute(page: const HostSetupScreen()));
        },
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Host Game', style: SeedlingTypography.body.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: CustomScrollView(
        slivers: [
          // High End Sliver App Bar
          SliverAppBar(
            backgroundColor: SeedlingColors.background,
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [SeedlingColors.deepRoot, SeedlingColors.morningDew],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('LIVE ARENA', style: SeedlingTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 8),
                        Text('Discovery Hub', style: SeedlingTypography.heading1.copyWith(color: Colors.white)),
                        Text('Join an active game or host your own.', style: SeedlingTypography.body.copyWith(color: Colors.white.withOpacity(0.8))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Filters
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Find by Category', style: SeedlingTypography.heading3),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(ref, 'All', activeFilter == null || activeFilter == 'All'),
                        _buildFilterChip(ref, 'Food & Dining', activeFilter == 'Food & Dining'),
                        _buildFilterChip(ref, 'Action Verbs', activeFilter == 'Action Verbs'),
                        _buildFilterChip(ref, 'Greetings', activeFilter == 'Greetings'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Active Games Grid/List
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: activeGames.isEmpty 
              ? SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Text('No active games in this category.', style: SeedlingTypography.body.copyWith(color: SeedlingColors.textSecondary, fontStyle: FontStyle.italic)),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildLiveGameCard(context, ref, activeGames[index]),
                    childCount: activeGames.length,
                  ),
                ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 100)), // FAB padding
        ],
      ),
    );
  }
  
  Widget _buildFilterChip(WidgetRef ref, String label, bool isActive) {
    return GestureDetector(
      onTap: () {
        ref.read(gameFilterProvider.notifier).state = label;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? SeedlingColors.seedlingGreen : SeedlingColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? Colors.transparent : SeedlingColors.morningDew.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: SeedlingTypography.caption.copyWith(
            color: isActive ? Colors.white : SeedlingColors.textPrimary,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildLiveGameCard(BuildContext context, WidgetRef ref, LiveGameSession game) {
    // Glassmorphism aesthetic
    return GestureDetector(
      onTap: () {
        ref.read(activeSessionProvider.notifier).joinAsSpectator(game);
        Navigator.push(context, SeedlingPageRoute(page: MultiplayerLobbyScreen(session: game)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: SeedlingColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: SeedlingColors.morningDew.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: SeedlingColors.sunlight.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ]
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Top right gradient glow
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [SeedlingColors.seedlingGreen.withOpacity(0.2), Colors.transparent],
                    ),
                  ),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: SeedlingColors.water.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            game.theme,
                            style: SeedlingTypography.caption.copyWith(color: SeedlingColors.water, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.people_alt_rounded, size: 16, color: SeedlingColors.textSecondary),
                            const SizedBox(width: 4),
                            Text('${game.playerCount}/${game.maxPlayers}', style: SeedlingTypography.caption.copyWith(color: SeedlingColors.textSecondary, fontWeight: FontWeight.bold)),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(game.title, style: SeedlingTypography.heading2),
                    const SizedBox(height: 4),
                    Text('Hosted by ${game.hostName}', style: SeedlingTypography.body.copyWith(color: SeedlingColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.timer_outlined, size: 14, color: SeedlingColors.sunlight),
                            const SizedBox(width: 4),
                            Text('${game.timePerQuestion}s/q', style: SeedlingTypography.caption),
                            const SizedBox(width: 12),
                            const Icon(Icons.quiz_outlined, size: 14, color: SeedlingColors.sunlight),
                            const SizedBox(width: 4),
                            Text('${game.totalQuestions} Qs', style: SeedlingTypography.caption),
                          ],
                        ),
                        Text(
                          'Spectate',
                          style: SeedlingTypography.body.copyWith(color: SeedlingColors.deepRoot, fontWeight: FontWeight.bold),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
