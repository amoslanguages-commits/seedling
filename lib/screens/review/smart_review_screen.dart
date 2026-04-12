import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors.dart';
import '../../core/typography.dart';
import '../../services/haptic_service.dart';
import '../../providers/app_providers.dart';
import '../../providers/review_provider.dart';
import '../../models/taxonomy.dart';
import 'mcq_review_session.dart';

import 'dart:ui';
import '../../widgets/tilt_card.dart';
import '../../widgets/premium_environment.dart';

class SmartReviewScreen extends ConsumerStatefulWidget {
  const SmartReviewScreen({super.key});

  @override
  ConsumerState<SmartReviewScreen> createState() => _SmartReviewScreenState();
}

class _SmartReviewScreenState extends ConsumerState<SmartReviewScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _entranceController;
  late List<Animation<double>> _staggeredAnims;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _staggeredAnims = List.generate(5, (index) {
      final start = index * 0.12;
      return CurvedAnimation(
        parent: _entranceController,
        curve: Interval(start, (start + 0.4).clamp(0.0, 1.0),
            curve: Curves.easeOutQuart),
      );
    });

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final dueStatus = ref.watch(smartFocusProvider);
    final stats = ref.watch(userStatsProvider);
    final timerMode = ref.watch(reviewTimerProvider);
    final topicsAsync = ref.watch(reviewTopicsProvider);

    return Scaffold(
      backgroundColor: SeedlingColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: false,
              title: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: SeedlingColors.cardBackground,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                ),
                child: Text(
                  'Watering Queue',
                  style: SeedlingTypography.heading1.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: -0.5,
                    color: SeedlingColors.textPrimary,
                  ),
                ),
              ),
              titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
              background: const SizedBox.shrink(),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeTransition(
                        opacity: _staggeredAnims[0],
                        child: SlideTransition(
                          position: _staggeredAnims[0].drive(
                            Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero),
                          ),
                          child: dueStatus.when(
                        data: (focus) => _buildIntegratedHub(focus.dueCount, totalLearned: focus.totalLearned),
                        loading: () => _buildIntegratedHub(0, totalLearned: 0, isLoading: true),
                        error: (_, __) => _buildIntegratedHub(0, totalLearned: 0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  FadeTransition(
                    opacity: _staggeredAnims[1],
                    child: _buildReflexPods(timerMode),
                  ),
                  const SizedBox(height: 40),
                  FadeTransition(
                    opacity: _staggeredAnims[2],
                    child: _buildTopicSection(topicsAsync),
                  ),
                  const SizedBox(height: 40),
                  FadeTransition(
                    opacity: _staggeredAnims[3],
                    child: stats.when(
                      data: (s) => _buildStatSection(s['totalLearned'] ?? 0),
                      loading: () => _buildStatSection(0),
                      error: (_, __) => _buildStatSection(0),
                    ),
                  ),
                  const SizedBox(height: 64),
                ],
              ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntegratedHub(int dueCount, {required int totalLearned, bool isLoading = false}) {
    final isDue = dueCount > 0;
    final isLocked = totalLearned <= 5;
    final needed = 6 - totalLearned;
    
    final List<Color> gradientColors = isLocked
        ? [const Color(0xFF48484A), const Color(0xFF2C2C2E)] // Dormant
        : isDue
            ? [const Color(0xFF1A7FBD), const Color(0xFF0D9488)] // Thirsty (Blue/Teal)
            : [const Color(0xFF2D7A3A), const Color(0xFF4CAF75)]; // Pristine (Green)
            
    final Color glowColor = isLocked ? Colors.transparent : gradientColors[0];
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: isLocked ? [] : [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: Status & Icon
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildAnimatedCore(isDue, isLocked),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isLocked ? 'LOCKED' : (isDue ? 'WATERING DUE' : 'FULLY WATERED'),
                          style: SeedlingTypography.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  isLocked ? 'Plant more seeds' : (isDue ? 'Plants are thirsty' : 'Garden is thriving'),
                  style: SeedlingTypography.heading2.copyWith(
                    color: Colors.white, 
                    fontSize: 22, 
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isLocked 
                     ? 'Learn $needed more words to start' 
                     : (isDue ? '$dueCount plants need water' : 'Your vocabulary is hydrated'),
                  style: SeedlingTypography.body.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Right: Action
          const SizedBox(width: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isLocked ? Colors.white.withValues(alpha: 0.1) : Colors.white,
              foregroundColor: isLocked ? Colors.white54 : glowColor,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: isLocked ? 0 : 4,
            ),
            onPressed: isLocked ? null : () async {
              HapticService.mediumImpact();
              await ref.read(reviewSessionProvider.notifier).startSession();
              if (mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const McqReviewSessionScreen()),
                );
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isLocked ? Icons.lock_outline_rounded : Icons.water_drop_rounded, size: 24),
                if (!isLocked && isDue) ...[
                  const SizedBox(width: 8),
                  Text('Water All', style: SeedlingTypography.body.copyWith(fontWeight: FontWeight.bold, color: glowColor)),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedCore(bool isDue, bool isLocked) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.2),
      duration: const Duration(seconds: 2),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: isDue && !isLocked ? value : 1.0,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              boxShadow: isDue && !isLocked ? [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: value * 2,
                )
              ] : [],
            ),
            alignment: Alignment.center,
            child: Text(isLocked ? '💤' : (isDue ? '💧' : '🌱'), style: const TextStyle(fontSize: 18)),
          ),
        );
      },
      onEnd: () {}, 
    );
  }

  Widget _buildReflexPods(ReviewTimerMode currentMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0),
          child: Text(
            'Watering Pace', 
            style: SeedlingTypography.heading3.copyWith(
              fontWeight: FontWeight.w900, 
              fontSize: 18,
              color: SeedlingColors.textPrimary,
            )
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: ReviewTimerMode.values.map((mode) {
              final isSelected = currentMode == mode;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: GestureDetector(
                  onTap: () {
                    HapticService.selectionClick();
                    ref.read(reviewTimerProvider.notifier).setMode(mode);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutQuart,
                    width: 80, // Fixed width prevents cramming
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: SeedlingColors.cardBackground,
                      gradient: isSelected ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          SeedlingColors.seedlingGreen.withValues(alpha: 0.2),
                          SeedlingColors.cardBackground,
                        ],
                      ) : null,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected 
                          ? SeedlingColors.seedlingGreen.withValues(alpha: 0.5) 
                          : Colors.white.withValues(alpha: 0.05),
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: SeedlingColors.seedlingGreen.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ] : [],
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(
                          mode == ReviewTimerMode.none ? Icons.spa_rounded : 
                          (mode == ReviewTimerMode.fifteen ? Icons.bolt_rounded : Icons.flash_on_rounded),
                          color: isSelected ? SeedlingColors.seedlingGreen : SeedlingColors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          mode.label,
                          style: SeedlingTypography.caption.copyWith(
                            color: isSelected ? Colors.white : SeedlingColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                            letterSpacing: 0.5,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTopicSection(AsyncValue<List<Map<String, dynamic>>> topicsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0),
          child: Text(
            'Targeted Pruning', 
            style: SeedlingTypography.heading3.copyWith(
              fontWeight: FontWeight.w900, 
              fontSize: 18,
              color: SeedlingColors.textPrimary,
            )
          ),
        ),
        const SizedBox(height: 16),
        topicsAsync.when(
          data: (allTopics) {
            final activeTopics = allTopics.where((t) => (t['total_learned'] as int) > 0).toList();
            if (activeTopics.isEmpty) return const SizedBox();
            
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 250,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 90, // Fixed height instead of aspect ratio
              ),
              itemCount: activeTopics.length,
              itemBuilder: (context, index) {
                   final topic = activeTopics[index];
                   final subDomainId = topic['sub_domain'] as String;
                   final dueCount = topic['due_count'] as int;
                   final totalLearned = topic['total_learned'] as int;
                   
                   final cat = CategoryTaxonomy.getCategory(subDomainId) ?? SemanticCategory(id: '?', name: subDomainId, icon: '🌱', color: Colors.grey);

                   return TiltCard(
                     maxTiltAngle: 0.15,
                     child: _buildTopicGem(cat, dueCount, totalLearned),
                   );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Text('Unable to load topics'),
        ),
      ],
    );
  }

  Widget _buildTopicGem(SemanticCategory cat, int dueCount, int totalLearned) {
    final isThirsty = dueCount > 0;
    final isLocked = totalLearned <= 5;
    final needed = 6 - totalLearned;
    final progress = (totalLearned / 20).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: isLocked ? null : () async {
        HapticService.selectionClick();
        await ref.read(reviewSessionProvider.notifier).startSession(subDomain: cat.id);
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const McqReviewSessionScreen()),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SeedlingColors.cardBackground,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isLocked ? [
              SeedlingColors.cardBackground.withValues(alpha: 0.5),
              SeedlingColors.cardBackground,
            ] : [
              cat.color.withValues(alpha: 0.12),
              SeedlingColors.cardBackground,
              SeedlingColors.cardBackground.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLocked 
                ? Colors.white.withValues(alpha: 0.05) 
                : cat.color.withValues(alpha: isThirsty ? 0.3 : 0.15),
            width: isThirsty ? 1.5 : 1,
          ),
          boxShadow: isThirsty ? [
            BoxShadow(
              color: cat.color.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ] : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isLocked ? Colors.white.withValues(alpha: 0.05) : cat.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Opacity(opacity: isLocked ? 0.5 : 1.0, child: Text(cat.icon, style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    cat.name,
                    style: SeedlingTypography.heading3.copyWith(
                      fontSize: 14, 
                      fontWeight: FontWeight.w900,
                      color: isLocked ? SeedlingColors.textSecondary : SeedlingColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  if (isLocked)
                     Text(
                       'Learn $needed more',
                       style: SeedlingTypography.caption.copyWith(
                         color: SeedlingColors.textSecondary.withValues(alpha: 0.6),
                         fontSize: 11,
                         fontWeight: FontWeight.w600,
                       ),
                     )
                  else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isThirsty ? '$dueCount thirsty' : 'Hydrated',
                          style: SeedlingTypography.caption.copyWith(
                            color: isThirsty ? cat.color : SeedlingColors.seedlingGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          progress < 0.25 ? '🫘' : progress < 0.6 ? '🌱' : progress < 0.9 ? '🌿' : '🌳',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 4,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress,
                        child: Container(
                          decoration: BoxDecoration(
                            color: cat.color,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: cat.color.withValues(alpha: 0.5),
                                blurRadius: 4,
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatSection(int totalLearned) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0),
          child: Text(
            'Garden Health', 
            style: SeedlingTypography.heading3.copyWith(
              fontWeight: FontWeight.w900, 
              fontSize: 18,
              color: SeedlingColors.textPrimary,
            )
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: SeedlingColors.cardBackground,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildAmbientStatItem('Roots', '84%', Icons.nature_rounded, SeedlingColors.royalPurple),
              _buildAmbientStatDivider(),
              _buildAmbientStatItem('Planted', totalLearned.toString(), Icons.grass_rounded, SeedlingColors.seedlingGreen),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmbientStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(
          value, 
          style: SeedlingTypography.heading2.copyWith(
            fontSize: 22, 
            fontWeight: FontWeight.w900,
            color: Colors.white,
          )
        ),
        Text(
          label.toUpperCase(), 
          style: SeedlingTypography.caption.copyWith(
            color: SeedlingColors.textSecondary, 
            fontWeight: FontWeight.w800,
            fontSize: 9,
            letterSpacing: 1.0,
          )
        ),
      ],
    );
  }

  Widget _buildAmbientStatDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }
}
