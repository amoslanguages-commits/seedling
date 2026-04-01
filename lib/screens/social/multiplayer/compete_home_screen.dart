import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/colors.dart';
import '../../../core/typography.dart';
import '../../../core/page_route.dart';
import '../../../models/multiplayer.dart';
import '../../../providers/multiplayer_provider.dart';
import 'host_setup_screen.dart';
import 'multiplayer_lobby_screen.dart';

class CompeteHomeScreen extends ConsumerWidget {
  const CompeteHomeScreen({super.key});

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
        label: Text('Host Arena', style: SeedlingTypography.body.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Premium Header
          SliverAppBar(
            backgroundColor: SeedlingColors.background,
            expandedHeight: 240,
            pinned: true,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [SeedlingColors.deepRoot, SeedlingColors.morningDew],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  // Abstract forest pattern
                  Positioned(
                    right: -20,
                    bottom: -20,
                    child: Opacity(
                      opacity: 0.2,
                      child: Icon(Icons.park_rounded, size: 200, color: Colors.white),
                    ),
                  ),
                  SafeArea(
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
                            child: Text('MULTIPLAYER ARENA', style: SeedlingTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                          ),
                          const SizedBox(height: 12),
                          Text('Global Discovery', style: SeedlingTypography.heading1.copyWith(color: Colors.white, fontSize: 32)),
                          const SizedBox(height: 4),
                          Text('Compete in real-time language battles. Join to play or watch.', style: SeedlingTypography.body.copyWith(color: Colors.white.withOpacity(0.8))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Filter Chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Active Arenas', style: SeedlingTypography.heading3),
                      Text('${activeGames.length} Live', style: SeedlingTypography.caption.copyWith(color: SeedlingColors.seedlingGreen, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildFilterChip(ref, 'All', activeFilter == null || activeFilter == 'All'),
                        _buildFilterChip(ref, 'Vocabulary', activeFilter == 'Vocabulary'),
                        _buildFilterChip(ref, 'Sentences', activeFilter == 'Sentences'),
                        _buildFilterChip(ref, 'Food & Dining', activeFilter == 'Food & Dining'),
                        _buildFilterChip(ref, 'Travel', activeFilter == 'Travel'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // List of Games
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            sliver: activeGames.isEmpty 
              ? SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Column(
                        children: [
                          Icon(Icons.grass_rounded, size: 48, color: SeedlingColors.morningDew),
                          const SizedBox(height: 16),
                          Text('No active arenas found.', style: SeedlingTypography.body.copyWith(color: SeedlingColors.textSecondary)),
                          Text('Try a different category or host one!', style: SeedlingTypography.caption),
                        ],
                      ),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildArenaCard(context, ref, activeGames[index]),
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
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? SeedlingColors.seedlingGreen : SeedlingColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isActive ? [
            BoxShadow(color: SeedlingColors.seedlingGreen.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
          ] : [],
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

  Widget _buildArenaCard(BuildContext context, WidgetRef ref, LiveGameSession game) {
    return GestureDetector(
      onTap: () {
        ref.read(activeSessionProvider.notifier).joinAsSpectator(game);
        Navigator.push(context, SeedlingPageRoute(page: MultiplayerLobbyScreen(session: game)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: SeedlingColors.cardBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: SeedlingColors.morningDew.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: SeedlingColors.deepRoot.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
          ]
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Banner Area
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 60,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        SeedlingColors.water.withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
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
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: SeedlingColors.morningDew.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Text(game.gameType == LiveGameType.vocabulary ? '🌸' : '🌳', style: const TextStyle(fontSize: 16)),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(game.title, style: SeedlingTypography.heading2.copyWith(fontSize: 18)),
                                Text('by ${game.hostName}', style: SeedlingTypography.caption.copyWith(color: SeedlingColors.textSecondary)),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: SeedlingColors.sunlight.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.people_alt_rounded, size: 14, color: SeedlingColors.sunlight),
                              const SizedBox(width: 6),
                              Text('${game.playerCount}/${game.maxPlayers}', style: SeedlingTypography.caption.copyWith(color: SeedlingColors.sunlight, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _buildInfoTag(Icons.category_outlined, game.theme),
                        const SizedBox(width: 12),
                        _buildInfoTag(Icons.timer_outlined, '${game.timePerQuestion}s'),
                        const SizedBox(width: 12),
                        _buildInfoTag(Icons.quiz_outlined, '${game.totalQuestions} Qs'),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: SeedlingColors.seedlingGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('LIVE LOBBY', style: SeedlingTypography.caption.copyWith(color: SeedlingColors.seedlingGreen, fontWeight: FontWeight.w800, letterSpacing: 1)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: SeedlingColors.deepRoot,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('WATCH', style: SeedlingTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
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

  Widget _buildInfoTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: SeedlingColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SeedlingColors.morningDew.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: SeedlingColors.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: SeedlingTypography.caption.copyWith(fontSize: 11, color: SeedlingColors.textSecondary)),
        ],
      ),
    );
  }
}
