import 'package:flutter/material.dart';
import '../core/page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/colors.dart';
import '../core/typography.dart';
import '../services/auth_service.dart';
import '../services/subscription_service.dart';
import '../models/gamification.dart';
import '../database/database_helper.dart';
import '../widgets/gamification_widgets.dart';
import '../providers/app_providers.dart';
import 'auth/auth_screen.dart';
import 'settings.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<UserProfileData> _profileFuture;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _profileFuture = _loadProfileData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<UserProfileData> _loadProfileData() async {
    final levelData = await XPManager.getLevelProgress();
    final streak = await StreakManager.getCurrentStreak();
    final stats = await DatabaseHelper().getUserStats();
    final achievementsCount = AchievementManager.achievements
        .where((a) => a.isUnlocked)
        .length;
    
    return UserProfileData(
      level: levelData.$1,
      currentXP: levelData.$2,
      xpForNextLevel: levelData.$3,
      streak: streak,
      totalWords: stats['totalWordsLearned'] ?? 0,
      totalMinutes: stats['totalStudyMinutes'] ?? 0,
      achievementsUnlocked: achievementsCount,
      totalAchievements: AchievementManager.achievements.length,
    );
  }
  
  Future<void> _refreshProfile() async {
    setState(() {
      _profileFuture = _loadProfileData();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final isAuthenticated = AuthService().isAuthenticated;
    final user = AuthService().currentUser;
    
    return Scaffold(
      backgroundColor: SeedlingColors.background,
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        color: SeedlingColors.seedlingGreen,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              backgroundColor: SeedlingColors.seedlingGreen,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildProfileHeader(context, isAuthenticated, user),
              ),
            ),
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: SeedlingColors.seedlingGreen,
                  labelColor: SeedlingColors.seedlingGreen,
                  unselectedLabelColor: SeedlingColors.textSecondary,
                  tabs: const [
                    Tab(icon: Icon(Icons.person), text: 'Overview'),
                    Tab(icon: Icon(Icons.emoji_events), text: 'Achievements'),
                    Tab(icon: Icon(Icons.history), text: 'Activity'),
                  ],
                ),
              ),
              pinned: true,
            ),
            SliverFillRemaining(
              child: FutureBuilder<UserProfileData>(
                future: _profileFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _OverviewTab(data: snapshot.data!),
                      const _AchievementsTab(),
                      const _ActivityTab(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProfileHeader(BuildContext context, bool isAuthenticated, User? user) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            SeedlingColors.background,
            SeedlingColors.deepRoot,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: IconButton(
                  icon: const Icon(Icons.settings, color: SeedlingColors.textSecondary),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
              ),
            ),
            Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: SeedlingColors.cardBackground,
                    shape: BoxShape.circle,
                    border: Border.all(color: SeedlingColors.seedlingGreen, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      isAuthenticated 
                          ? (user?.email?[0] ?? '👤').toUpperCase()
                          : '👤',
                      style: const TextStyle(
                        fontSize: 40,
                        color: SeedlingColors.seedlingGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (SubscriptionService().isPremium)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: SeedlingColors.sunlight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.star,
                        color: SeedlingColors.textPrimary,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              isAuthenticated 
                  ? (user?.userMetadata?['display_name'] ?? 'Learner')
                  : 'Guest Learner',
              style: SeedlingTypography.heading2.copyWith(
                color: SeedlingColors.textPrimary,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              isAuthenticated 
                  ? (user?.email ?? '')
                  : 'Sign in to sync your progress',
              style: SeedlingTypography.body.copyWith(
                color: SeedlingColors.textSecondary,
              ),
            ),
            if (!isAuthenticated) ...[
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    SeedlingPageRoute(page: const AuthScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: SeedlingColors.seedlingGreen,
                  foregroundColor: SeedlingColors.textPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text('Sign In'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final UserProfileData data;
  
  const _OverviewTab({required this.data});
  
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildLevelCard(data),
        const SizedBox(height: 20),
        _buildStreakCard(data.streak),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                '📚',
                '${data.totalWords}',
                'Words',
                SeedlingColors.seedlingGreen,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildStatCard(
                '⏱️',
                '${data.totalMinutes}',
                'Minutes',
                SeedlingColors.water,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildStatCard(
                '🏆',
                '${data.achievementsUnlocked}',
                'Achievements',
                SeedlingColors.sunlight,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  // Internal card and tile builders...
  Widget _buildLevelCard(UserProfileData data) {
      final progress = data.currentXP / data.xpForNextLevel;
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              SeedlingColors.sunlight,
              SeedlingColors.sunlight.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: SeedlingColors.sunlight.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: SeedlingColors.background.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: SeedlingColors.morningDew.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Lv. ${data.level}',
                        style: SeedlingTypography.heading2.copyWith(
                          color: SeedlingColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Level ${data.level}',
                          style: SeedlingTypography.heading3.copyWith(
                            color: SeedlingColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${data.xpForNextLevel - data.currentXP} XP to next level',
                          style: SeedlingTypography.caption.copyWith(
                            color: SeedlingColors.textPrimary.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: SeedlingTypography.heading2.copyWith(
                    color: SeedlingColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: SeedlingColors.textPrimary.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(SeedlingColors.textPrimary),
                minHeight: 12,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${data.currentXP} / ${data.xpForNextLevel} XP',
              style: SeedlingTypography.caption.copyWith(
                color: SeedlingColors.textPrimary.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildStreakCard(int streak) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: SeedlingColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: SeedlingColors.morningDew.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            StreakFlame(streak: streak, size: 80),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$streak Day Streak',
                    style: SeedlingTypography.heading3,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    streak > 0 
                        ? 'Keep it up! You\'re on fire! 🔥'
                        : 'Start your streak today!',
                    style: SeedlingTypography.caption,
                  ),
                  if (streak > 0) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: List.generate(7, (index) {
                        final isActive = index < (streak % 7);
                        return Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: isActive 
                                ? SeedlingColors.sunlight 
                                : SeedlingColors.background.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: isActive 
                              ? const Icon(Icons.check, color: SeedlingColors.deepRoot, size: 12)
                              : null,
                        );
                      }),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildStatCard(String emoji, String value, String label, Color color) {
      return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: SeedlingColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(
              value,
              style: SeedlingTypography.heading2.copyWith(color: color),
            ),
            Text(
              label,
              style: SeedlingTypography.caption,
            ),
          ],
        ),
      );
  }
}

class _AchievementsTab extends StatelessWidget {
  const _AchievementsTab();
  
  @override
  Widget build(BuildContext context) {
    final achievements = AchievementManager.achievements;
    final unlockedCount = achievements.where((a) => a.isUnlocked).length;
    
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                SeedlingColors.seedlingGreen,
                SeedlingColors.deepRoot,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Achievement Progress',
                      style: SeedlingTypography.body.copyWith(
                        color: SeedlingColors.background.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$unlockedCount / ${achievements.length}',
                      style: SeedlingTypography.heading1.copyWith(
                        color: SeedlingColors.background,
                      ),
                    ),
                  ],
                ),
              ),
              CircularProgressIndicator(
                value: unlockedCount / achievements.length,
                backgroundColor: SeedlingColors.background.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(SeedlingColors.sunlight),
                strokeWidth: 8,
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          childAspectRatio: 0.75,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          children: achievements.map((achievement) {
            return AchievementBadge(achievement: achievement);
          }).toList(),
        ),
      ],
    );
  }
}

class _ActivityTab extends ConsumerWidget {
  const _ActivityTab();
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(recentActivityProvider);
    
    return activityAsync.when(
      data: (words) {
         if (words.isEmpty) {
           return ListView(
             padding: const EdgeInsets.all(20),
             children: [
               Text('Recent Activity', style: SeedlingTypography.heading3),
               const SizedBox(height: 15),
               const Text('No recent activity yet. Keep learning!'),
             ],
           );
         }
         
         final activities = words.map((word) {
           final isMastered = word.masteryLevel >= 5;
           final String action = isMastered ? 'Mastered' : 'Reviewed';
           final String lang = word.languageCode.toUpperCase();
           final String catStr = word.categoryIds.isNotEmpty 
               ? word.categoryIds.first 
               : 'General';
           final String cat = catStr.isNotEmpty ? 
               catStr[0].toUpperCase() + catStr.substring(1) : 'General';
           final int xpEarned = isMastered ? 50 : 10;
           
           return ActivityItem(
             icon: isMastered ? Icons.star : Icons.book,
             title: '$action "${word.translation}"',
             subtitle: '$lang • $cat',
             time: 'Recently',
             xp: xpEarned,
           );
         }).toList();

         return ListView(
           padding: const EdgeInsets.all(20),
           children: [
             Text(
               'Recent Activity',
               style: SeedlingTypography.heading3,
             ),
             const SizedBox(height: 15),
             ...activities.map((activity) => _buildActivityTile(activity)),
           ],
         );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: SeedlingColors.seedlingGreen)),
      error: (err, _) => const Center(child: Text('Error loading activity')),
    );
  }
  
  Widget _buildActivityTile(ActivityItem activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SeedlingColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: SeedlingColors.morningDew.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(activity.icon, color: SeedlingColors.seedlingGreen),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: SeedlingTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  activity.subtitle,
                  style: SeedlingTypography.caption,
                ),
                const SizedBox(height: 4),
                Text(
                  activity.time,
                  style: SeedlingTypography.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          if (activity.xp > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: SeedlingColors.sunlight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '+${activity.xp}',
                style: SeedlingTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class UserProfileData {
  final int level;
  final int currentXP;
  final int xpForNextLevel;
  final int streak;
  final int totalWords;
  final int totalMinutes;
  final int achievementsUnlocked;
  final int totalAchievements;
  
  UserProfileData({
    required this.level,
    required this.currentXP,
    required this.xpForNextLevel,
    required this.streak,
    required this.totalWords,
    required this.totalMinutes,
    required this.achievementsUnlocked,
    required this.totalAchievements,
  });
}

class ActivityItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final int xp;
  
  ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.xp,
  });
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  
  _SliverAppBarDelegate(this._tabBar);
  
  @override
  double get minExtent => _tabBar.preferredSize.height;
  
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: SeedlingColors.background,
      child: _tabBar,
    );
  }
  
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
