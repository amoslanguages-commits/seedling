import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/colors.dart';
import '../core/typography.dart';
import '../core/app_utils.dart';
import '../core/page_route.dart';
import '../widgets/mascot.dart';
import '../widgets/cards.dart';
import '../widgets/buttons.dart';
import '../widgets/progress.dart';
import '../widgets/botanical_refresh.dart';
import '../providers/app_providers.dart';
import 'settings.dart';
import 'learning.dart';
import '../services/audio_service.dart';
import '../services/notification_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Mascot encouragement overlay
  String? _mascotMessage;

  static const _mascotMessages = [
    'Every word is a new root! 🌿',
    'You are growing every day! 🌱',
    'Keep planting! The garden awaits 🏡',
    'Words remembered = roots deepened 🌳',
    'Your vocabulary garden is thriving!',
    'One word at a time — that\'s how forests grow 🌲',
  ];

  void _onMascotTap(int streak) {
    const msgs = _mascotMessages;
    final msg = streak >= 3
        ? '$streak-day streak! ${msgs[streak % msgs.length]}'
        : msgs[DateTime.now().second % msgs.length];
    setState(() => _mascotMessage = msg);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _mascotMessage = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(userStatsProvider);
    final categoriesAsync = ref.watch(categoryStatsProvider);
    final activityAsync = ref.watch(recentActivityProvider);

    return Scaffold(
      backgroundColor: SeedlingColors.background,
      body: SafeArea(
        child: BotanicalRefreshWrapper(
          onRefresh: () async {
            ref.invalidate(userStatsProvider);
            ref.invalidate(categoryStatsProvider);
            ref.invalidate(recentActivityProvider);
            // Brief delay for the bloom animation to finish gracefully
            await Future.delayed(const Duration(milliseconds: 600));
          },
          child: CustomScrollView(
          slivers: [
            // App Bar with Mascot
            SliverToBoxAdapter(
              child: statsAsync.when(
                data: (stats) {
                  final streak = (stats['currentStreak'] as int?) ?? 0;
                  final totalLearned = (stats['totalLearned'] as int?) ?? 0;
                  final practicedToday = ((stats['dailyProgress'] as int?) ?? 0) > 0;

                  // Schedule daily reminder based on session status
                  NotificationService.instance
                      .ensureEveningReminderScheduled(practicedToday)
                      .ignore();

                  final mascotState = streak == 0
                      ? MascotState.sad
                      : practicedToday
                          ? MascotState.happy
                          : MascotState.idle;

                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _onMascotTap(streak),
                              child: SeedlingMascot(
                                size: 60,
                                state: mascotState,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    buildGreeting(
                                      streak: streak,
                                      practicedToday: practicedToday,
                                    ),
                                    style: SeedlingTypography.heading3,
                                  ),
                                  Text(
                                    buildSubtitle(
                                      totalLearned: totalLearned,
                                      practicedToday: practicedToday,
                                    ),
                                    style: SeedlingTypography.caption,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.settings_outlined),
                              color: SeedlingColors.textPrimary,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  SeedlingPageRoute(
                                    page: const SettingsScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        // Mascot message bubble
                        if (_mascotMessage != null) ...[
                          const SizedBox(height: 10),
                          AnimatedOpacity(
                            opacity: _mascotMessage != null ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: SeedlingColors.seedlingGreen.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: SeedlingColors.seedlingGreen.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.eco_rounded,
                                      color: SeedlingColors.seedlingGreen, size: 16),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _mascotMessage!,
                                      style: SeedlingTypography.caption.copyWith(
                                        color: SeedlingColors.deepRoot,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      SeedlingMascot(size: 60, state: MascotState.idle),
                      SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Welcome back!', style: SeedlingTypography.heading3),
                            Text('Loading your garden...', style: SeedlingTypography.caption),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            // Stats & Content
            SliverToBoxAdapter(
              child: statsAsync.when(
                data: (stats) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Daily Progress Card
                      GrowingCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Today\'s Growth',
                                  style: SeedlingTypography.heading3,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: SeedlingColors.morningDew.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${stats['dailyProgress']}/${stats['dailyGoal']} words',
                                    style: SeedlingTypography.caption.copyWith(
                                      color: SeedlingColors.deepRoot,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            StemProgressBar(
                              progress: stats['dailyProgress'] / stats['dailyGoal'],
                              height: 10,
                            ),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                _buildStatItem(
                                  Icons.local_fire_department,
                                  '${stats['currentStreak']}',
                                  'Day streak',
                                  SeedlingColors.sunlight,
                                ),
                                const SizedBox(width: 20),
                                _buildStatItem(
                                  Icons.book,
                                  '${stats['totalLearned']}',
                                  'Words learned',
                                  SeedlingColors.water,
                                ),
                                const SizedBox(width: 20),
                                _buildStatItem(
                                  Icons.timer,
                                  '${stats['totalMinutes']}',
                                  'Minutes',
                                  SeedlingColors.freshSprout,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Start Learning Button
                      OrganicButton(
                        text: 'Start Learning Session',
                        onPressed: () {
                          AudioService.instance.play(SFX.buttonTap);
                          Navigator.push(
                            context,
                            SeedlingPageRoute(page: const LearningSessionScreen()),
                          );
                        },
                        height: 64,
                      ),

                      const SizedBox(height: 30),

                      // Categories Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Categories',
                            style: SeedlingTypography.heading2,
                          ),
                          TextButton(
                            onPressed: () {},
                            child: Text(
                              'See all',
                              style: SeedlingTypography.caption.copyWith(
                                color: SeedlingColors.seedlingGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      // Category Grid
                      categoriesAsync.when(
                        data: (categories) {
                          if (categories.isEmpty) {
                            return const Center(child: Text('No categories found.'));
                          }
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 15,
                              crossAxisSpacing: 15,
                              childAspectRatio: 1.3,
                            ),
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final cat = categories[index];
                              final String name = cat['category'];
                              final int count = cat['total'];

                              return _buildCategoryCard(
                                context,
                                name,
                                name[0].toUpperCase() + name.substring(1),
                                _getIconForCategory(name),
                                _getColorForCategory(name),
                                count,
                              );
                            },
                          );
                        },
                        loading: () => const Center(
                            child: CircularProgressIndicator(color: SeedlingColors.seedlingGreen)),
                        error: (err, _) => const Center(child: Text('Error loading categories')),
                      ),

                      const SizedBox(height: 30),

                      // Recent Activity
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Activity',
                            style: SeedlingTypography.heading2,
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      activityAsync.when(
                        data: (recentWords) {
                          if (recentWords.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Text('No recent activity yet. Plant some seeds!',
                                  style: SeedlingTypography.caption),
                            );
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: recentWords.length,
                            itemBuilder: (context, index) {
                              final word = recentWords[index];
                              final lang = word.languageCode.toUpperCase();
                              final isMastered = word.masteryLevel >= 5;
                              final action = isMastered ? 'Mastered' : 'Reviewed';
                              final color = isMastered
                                  ? SeedlingColors.seedlingGreen
                                  : SeedlingColors.water;

                              final catLabel = word.categoryIds.isNotEmpty
                                  ? word.categoryIds.first
                                  : '';
                              final catDisplay = catLabel.isNotEmpty
                                  ? catLabel[0].toUpperCase() + catLabel.substring(1)
                                  : 'General';

                              // Real relative timestamp
                              final timeStr = relativeTime(word.lastReviewed);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _buildActivityItem(
                                  '$action "${word.translation}"',
                                  '$lang • $catDisplay',
                                  timeStr,
                                  color,
                                ),
                              );
                            },
                          );
                        },
                        loading: () => const Center(
                            child: CircularProgressIndicator(color: SeedlingColors.seedlingGreen)),
                        error: (err, _) =>
                            const Center(child: Text('Error loading activity')),
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: SeedlingColors.seedlingGreen,
                  ),
                ),
                error: (err, _) => const Center(
                  child: Text('Failed to load stats'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: SeedlingTypography.heading3.copyWith(fontSize: 18),
              ),
              Text(
                label,
                style: SeedlingTypography.caption.copyWith(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    String rawName,
    String title,
    IconData icon,
    Color color,
    int wordCount,
  ) {
    return GrowingCard(
      onTap: () {
        AudioService.instance.play(SFX.navTap);
        Navigator.push(
          context,
          SeedlingPageRoute(
            page: LearningSessionScreen(categoryId: rawName),
          ),
        );
      },
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: SeedlingTypography.heading3.copyWith(fontSize: 16),
              ),
              Text(
                '$wordCount words',
                style: SeedlingTypography.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String subtitle,
    String time,
    Color indicatorColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
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
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: indicatorColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SeedlingTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: SeedlingColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: SeedlingTypography.caption,
                ),
              ],
            ),
          ),
          Text(
            time,
            style: SeedlingTypography.caption.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }

  IconData _getIconForCategory(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('fruit') || lower.contains('food')) return Icons.apple;
    if (lower.contains('nature') || lower.contains('plant')) return Icons.nature;
    if (lower.contains('emotion')) return Icons.favorite;
    if (lower.contains('people') || lower.contains('body')) return Icons.people;
    if (lower.contains('communic') || lower.contains('greet')) return Icons.waving_hand;
    if (lower.contains('move') || lower.contains('action') || lower.contains('verb')) {
      return Icons.directions_run;
    }
    if (lower.contains('time') || lower.contains('day')) return Icons.access_time;
    if (lower.contains('animal')) return Icons.pets;
    if (lower.contains('number')) return Icons.numbers;
    if (lower.contains('color')) return Icons.color_lens;
    return Icons.category;
  }

  Color _getColorForCategory(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('fruit') || lower.contains('food')) return SeedlingColors.water;
    if (lower.contains('nature') || lower.contains('plant')) return SeedlingColors.freshSprout;
    if (lower.contains('emotion')) return SeedlingColors.error.withValues(alpha: 0.7);
    if (lower.contains('people') || lower.contains('body')) return SeedlingColors.sunlight;
    if (lower.contains('communic') || lower.contains('greet')) return SeedlingColors.water;
    if (lower.contains('animal')) return Colors.orange;
    return SeedlingColors.seedlingGreen;
  }
}
