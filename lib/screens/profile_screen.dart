import 'dart:math' as math;
import 'dart:ui';
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

// ── Achievement Rarity ────────────────────────────────────────────────────────

enum _Rarity { common, rare, legendary }

_Rarity _rarityFor(String id) {
  switch (id) {
    case 'top_learner':
      return _Rarity.legendary;
    case 'polyglot':
    case 'streak_7':
      return _Rarity.rare;
    default:
      return _Rarity.common;
  }
}

Color _rarityColor(_Rarity r) {
  switch (r) {
    case _Rarity.legendary:
      return SeedlingColors.autumnGold;
    case _Rarity.rare:
      return SeedlingColors.royalPurple;
    case _Rarity.common:
      return SeedlingColors.morningDew;
  }
}

String _rarityLabel(_Rarity r) {
  switch (r) {
    case _Rarity.legendary:
      return 'LEGENDARY';
    case _Rarity.rare:
      return 'RARE';
    case _Rarity.common:
      return 'COMMON';
  }
}

// ── Main Screen ───────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late Future<UserProfileData> _profileFuture;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late AnimationController _countUpController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _profileFuture = _loadProfileData();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _countUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    _countUpController.dispose();
    super.dispose();
  }

  Future<UserProfileData> _loadProfileData() async {
    final levelData = await XPManager.getLevelProgress();
    final streak = await StreakManager.getCurrentStreak();
    final stats = await DatabaseHelper().getUserStats();
    final achievements = await AchievementManager.getAchievements();
    final achievementsCount = achievements.where((a) => a.isUnlocked).length;

    return UserProfileData(
      level: levelData.$1,
      currentXP: levelData.$2,
      xpForNextLevel: levelData.$3,
      streak: streak,
      totalWords: stats['totalWordsLearned'] ?? 0,
      totalMinutes: stats['totalStudyMinutes'] ?? 0,
      achievementsUnlocked: achievementsCount,
      totalAchievements: achievements.length,
      achievements: achievements,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = AuthService().isAuthenticated;
    final user = AuthService().currentUser;

    return Scaffold(
      backgroundColor: SeedlingColors.background,
      body: FutureBuilder<UserProfileData>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: SeedlingColors.seedlingGreen,
              ),
            );
          }
          final data = snapshot.data!;

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 380,
                  pinned: true,
                  backgroundColor: SeedlingColors.background,
                  flexibleSpace: FlexibleSpaceBar(
                    background: _buildProfileHeader(
                      context,
                      isAuthenticated,
                      user,
                      data,
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  delegate: _SliverTabBarDelegate(_buildSlidingTabBar()),
                  pinned: true,
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _OverviewTab(
                  data: data,
                  shimmerController: _shimmerController,
                  countUpController: _countUpController,
                  pulseController: _pulseController,
                ),
                _AchievementsTab(
                  achievements: data.achievements,
                  shimmerController: _shimmerController,
                  pulseController: _pulseController,
                ),
                _ActivityTab(shimmerController: _shimmerController),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── HEADER ── ───────────────────────────────────────────────────────────────

  Widget _buildProfileHeader(
    BuildContext context,
    bool isAuthenticated,
    User? user,
    UserProfileData data,
  ) {
    return Stack(
      children: [
        // Gradient mesh orbs
        _buildHeaderMesh(),
        SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 4),
              // Settings button top-right
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: IconButton(
                    icon: const Icon(
                      Icons.settings_rounded,
                      color: SeedlingColors.textSecondary,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                  ),
                ),
              ),
              // Avatar with glow ring
              _buildGlowAvatar(isAuthenticated, user, data.level),
              const SizedBox(height: 16),
              // Name
              Text(
                isAuthenticated
                    ? (user?.userMetadata?['display_name'] ?? 'Learner')
                    : 'Guest Learner',
                style: SeedlingTypography.heading2.copyWith(
                  color: SeedlingColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isAuthenticated
                    ? (user?.email ?? '')
                    : 'Sign in to sync your progress',
                style: SeedlingTypography.body.copyWith(
                  color: SeedlingColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              if (!isAuthenticated) ...[
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    SeedlingPageRoute(page: const AuthScreen()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          SeedlingColors.seedlingGreen,
                          SeedlingColors.freshSprout,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Text(
                      'Sign In',
                      style: SeedlingTypography.body.copyWith(
                        color: SeedlingColors.deepRoot,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // Stat pills row
              _buildStatPillsRow(data),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderMesh() {
    return Stack(
      children: [
        // Orb 1 — Green top
        Positioned(
          top: -60,
          left: -60,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  SeedlingColors.seedlingGreen.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Orb 2 — Gold right
        AnimatedBuilder(
          animation: _pulseController,
          builder: (_, __) => Positioned(
            top: 60 + _pulseController.value * 15,
            right: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    SeedlingColors.autumnGold.withValues(
                      alpha: 0.07 + 0.04 * _pulseController.value,
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        // Orb 3 — Blue bottom-left
        Positioned(
          bottom: 0,
          left: -40,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  SeedlingColors.water.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: Container(color: Colors.transparent),
          ),
        ),
      ],
    );
  }

  Widget _buildGlowAvatar(bool isAuthenticated, User? user, int level) {
    // #4 — Use display_name initial, fall back to email, never raw email[0]
    final letter = isAuthenticated
        ? ((user?.userMetadata?['display_name'] as String? ??
                user?.email ??
                '?')[0])
            .toUpperCase()
        : '👤';

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Rotating multi-stop glow ring
            Transform.rotate(
              angle: _pulseController.value * 2 * math.pi,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      SeedlingColors.seedlingGreen.withValues(alpha: 0.0),
                      SeedlingColors.seedlingGreen.withValues(alpha: 0.3),
                      SeedlingColors.freshSprout.withValues(alpha: 0.5),
                      SeedlingColors.autumnGold.withValues(alpha: 0.3),
                      SeedlingColors.seedlingGreen.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                  ),
                ),
              ),
            ),
            // Inner glowing blur
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: SeedlingColors.seedlingGreen.withValues(
                      alpha: 0.15 + 0.1 * _pulseController.value,
                    ),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),
            // Main avatar container
            Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    SeedlingColors.deepRoot,
                    SeedlingColors.deepRoot.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: SeedlingColors.seedlingGreen.withValues(
                    alpha: 0.6 + 0.2 * _pulseController.value,
                  ),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Center(
                child: isAuthenticated
                    ? Text(
                        letter,
                        style: SeedlingTypography.heading1.copyWith(
                          fontSize: 48,
                          color: SeedlingColors.seedlingGreen,
                          shadows: [
                            Shadow(
                              color: SeedlingColors.seedlingGreen.withValues(
                                alpha: 0.5,
                              ),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      )
                    : const Text('👤', style: TextStyle(fontSize: 48)),
              ),
            ),
            // Level badge floating pill
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [SeedlingColors.autumnGold, SeedlingColors.warning],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: SeedlingColors.background,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: SeedlingColors.autumnGold.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'LV. $level',
                  style: SeedlingTypography.caption.copyWith(
                    color: SeedlingColors.deepRoot,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            // Premium star
            if (SubscriptionService().isPremium)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    gradient: const RadialGradient(
                      colors: [
                        SeedlingColors.autumnGold,
                        SeedlingColors.warning,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: SeedlingColors.autumnGold.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                    border: Border.all(
                      color: SeedlingColors.background,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: Colors.black87,
                    size: 14,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStatPillsRow(UserProfileData data) {
    return AnimatedBuilder(
      animation: _countUpController,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStatPill(
              '🔥',
              '${(data.streak * _countUpController.value).toInt()}d',
              'Streak',
              SeedlingColors.warning,
            ),
            const SizedBox(width: 10),
            _buildStatPill(
              '📚',
              '${(data.totalWords * _countUpController.value).toInt()}',
              'Words',
              SeedlingColors.seedlingGreen,
            ),
            const SizedBox(width: 10),
            _buildStatPill(
              '⭐',
              'Lv.${data.level}',
              'Level',
              SeedlingColors.autumnGold,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatPill(String emoji, String value, String label, Color color) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: SeedlingColors.cardBackground.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.3 + 0.1 * _pulseController.value),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 14)),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: SeedlingTypography.body.copyWith(
                    color: SeedlingColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  label.toUpperCase(),
                  style: SeedlingTypography.caption.copyWith(
                    fontSize: 8,
                    color: SeedlingColors.textSecondary,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── SLIDING TAB BAR ──────────────────────────────────────────────────────────

  Widget _buildSlidingTabBar() {
    return Container(
      color: SeedlingColors.background,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: SeedlingColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: SeedlingColors.morningDew.withValues(alpha: 0.15),
          ),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                SeedlingColors.seedlingGreen,
                SeedlingColors.freshSprout,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: SeedlingColors.seedlingGreen.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: SeedlingColors.deepRoot,
          unselectedLabelColor: SeedlingColors.textSecondary,
          labelStyle: SeedlingTypography.caption.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: SeedlingTypography.caption.copyWith(
            fontWeight: FontWeight.normal,
            fontSize: 12,
          ),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Achievements'),
            Tab(text: 'Activity'),
          ],
        ),
      ),
    );
  }
}

// ── Overview Tab ──────────────────────────────────────────────────────────────

class _OverviewTab extends ConsumerWidget {
  final UserProfileData data;
  final AnimationController shimmerController;
  final AnimationController countUpController;
  final AnimationController pulseController;

  const _OverviewTab({
    required this.data,
    required this.shimmerController,
    required this.countUpController,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // #11 — Wire sparklines to real weekly data
    final weeklyAsync = ref.watch(weeklyStudyStatsProvider);

    return weeklyAsync.when(
      loading: () => _buildContent(context, null, null),
      error: (_, __) => _buildContent(context, null, null),
      data: (weekly) => _buildContent(
        context,
        (weekly['words'] ?? []).map((v) => (v as num).toDouble()).toList(),
        (weekly['minutes'] ?? []).map((v) => (v as num).toDouble()).toList(),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<double>? wordData, List<double>? minuteData) {
    // Fall back to zeros if no data yet (new user)
    final wordsSparkline = wordData ?? List<double>.filled(7, 0);
    final minutesSparkline = minuteData ?? List<double>.filled(7, 0);
    const badgesSparkline = <double>[1, 1, 2, 2, 2, 3, 3];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildLevelRingCard(),
        const SizedBox(height: 20),
        _buildStreakCard(),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildSparklineStatCard(
                '📚',
                data.totalWords,
                'Words',
                SeedlingColors.seedlingGreen,
                wordsSparkline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSparklineStatCard(
                '⏱️',
                data.totalMinutes,
                'Minutes',
                SeedlingColors.water,
                minutesSparkline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSparklineStatCard(
                '🏆',
                data.achievementsUnlocked,
                'Badges',
                SeedlingColors.autumnGold,
                badgesSparkline,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLevelRingCard() {
    final progress = data.currentXP / data.xpForNextLevel;

    return AnimatedBuilder(
      animation: countUpController,
      builder: (_, __) {
        final animatedProgress = progress * countUpController.value;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                SeedlingColors.cardBackground,
                SeedlingColors.cardBackground.withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: SeedlingColors.autumnGold.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: SeedlingColors.autumnGold.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Background pattern (subtle)
              Positioned(
                right: -20,
                bottom: -20,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 100,
                  color: SeedlingColors.autumnGold.withValues(alpha: 0.05),
                ),
              ),
              Row(
                children: [
                  // Circular XP Ring with Glow
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: SeedlingColors.autumnGold.withValues(
                                alpha: 0.1,
                              ),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 90,
                        height: 90,
                        child: CustomPaint(
                          painter: _XPRingPainter(progress: animatedProgress),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${data.level}',
                                  style: SeedlingTypography.heading1.copyWith(
                                    color: SeedlingColors.autumnGold,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  'LEVEL',
                                  style: SeedlingTypography.caption.copyWith(
                                    fontSize: 7,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.bold,
                                    color: SeedlingColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Forest Guardian',
                              style: SeedlingTypography.heading3.copyWith(
                                color: SeedlingColors.textPrimary,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: SeedlingColors.autumnGold,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${data.xpForNextLevel - data.currentXP} XP to next level',
                          style: SeedlingTypography.caption.copyWith(
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Premium Progress Bar
                        Stack(
                          children: [
                            Container(
                              height: 10,
                              decoration: BoxDecoration(
                                color: SeedlingColors.deepRoot.withValues(
                                  alpha: 0.3,
                                ),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: animatedProgress,
                              child: Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      SeedlingColors.autumnGold,
                                      SeedlingColors.warning,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: SeedlingColors.autumnGold
                                          .withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${data.currentXP} XP',
                              style: SeedlingTypography.caption.copyWith(
                                color: SeedlingColors.autumnGold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Target: ${data.xpForNextLevel} XP',
                              style: SeedlingTypography.caption.copyWith(
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStreakCard() {
    return _AnimatedStreakCard(
      streak: data.streak,
      pulseController: pulseController,
    );
  }

  Widget _buildSparklineStatCard(
    String emoji,
    int value,
    String label,
    Color color,
    List<double> sparkData,
  ) {
    return AnimatedBuilder(
      animation: countUpController,
      builder: (_, __) {
        final animValue = (value * countUpController.value).toInt();
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: SeedlingColors.cardBackground,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 12),
            ],
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 6),
              Text(
                '$animValue',
                style: SeedlingTypography.heading2.copyWith(color: color),
              ),
              Text(label, style: SeedlingTypography.caption),
              const SizedBox(height: 8),
              // Sparkline
              SizedBox(
                height: 28,
                child: CustomPaint(
                  painter: _SparklinePainter(data: sparkData, color: color),
                  size: Size.infinite,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Animated Streak Card ──────────────────────────────────────────────────────

class _AnimatedStreakCard extends StatefulWidget {
  final int streak;
  final AnimationController pulseController;

  const _AnimatedStreakCard({
    required this.streak,
    required this.pulseController,
  });

  @override
  State<_AnimatedStreakCard> createState() => _AnimatedStreakCardState();
}

class _AnimatedStreakCardState extends State<_AnimatedStreakCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800 + widget.streak * 80),
    )..forward();
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_dotController, widget.pulseController]),
      builder: (_, __) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: SeedlingColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.streak > 0
                  ? SeedlingColors.warning.withValues(
                      alpha: 0.2 + 0.15 * widget.pulseController.value,
                    )
                  : SeedlingColors.morningDew.withValues(alpha: 0.2),
            ),
            boxShadow: widget.streak > 0
                ? [
                    BoxShadow(
                      color: SeedlingColors.warning.withValues(
                        alpha: 0.08 * widget.pulseController.value,
                      ),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              StreakFlame(streak: widget.streak, size: 80),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero streak number with shimmer
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: widget.streak > 0
                            ? [
                                SeedlingColors.warning,
                                SeedlingColors.sunlight,
                                SeedlingColors.warning,
                              ]
                            : [
                                SeedlingColors.textSecondary,
                                SeedlingColors.textSecondary,
                              ],
                        stops: widget.streak > 0
                            ? [
                                (widget.pulseController.value - 0.3).clamp(
                                  0.0,
                                  1.0,
                                ),
                                widget.pulseController.value,
                                (widget.pulseController.value + 0.3).clamp(
                                  0.0,
                                  1.0,
                                ),
                              ]
                            : [0.0, 1.0],
                      ).createShader(bounds),
                      child: Text(
                        '${widget.streak} Day${widget.streak != 1 ? 's' : ''}',
                        style: SeedlingTypography.heading3.copyWith(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.streak > 0
                          ? 'Keep it up! You\'re on fire! 🔥'
                          : 'Start your streak today!',
                      style: SeedlingTypography.caption,
                    ),
                    if (widget.streak > 0) ...[
                      const SizedBox(height: 10),
                      // Animated dot reveal
                      Row(
                        children: List.generate(7, (i) {
                          final activeCount = widget.streak % 7;
                          final revealProgress = (_dotController.value * 7 - i)
                              .clamp(0.0, 1.0);
                          final isActive = i < activeCount;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 22,
                            height: 22,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? SeedlingColors.warning.withValues(
                                      alpha: revealProgress,
                                    )
                                  : SeedlingColors.morningDew.withValues(
                                      alpha: 0.1,
                                    ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isActive
                                    ? SeedlingColors.warning.withValues(
                                        alpha: revealProgress,
                                      )
                                    : SeedlingColors.morningDew.withValues(
                                        alpha: 0.2,
                                      ),
                              ),
                            ),
                            child: isActive
                                ? Center(
                                    child: Opacity(
                                      opacity: revealProgress,
                                      child: const Icon(
                                        Icons.check_rounded,
                                        color: SeedlingColors.deepRoot,
                                        size: 13,
                                      ),
                                    ),
                                  )
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
      },
    );
  }
}

// ── Achievements Tab ──────────────────────────────────────────────────────────

class _AchievementsTab extends StatelessWidget {
  final List<Achievement> achievements;
  final AnimationController shimmerController;
  final AnimationController pulseController;

  const _AchievementsTab({
    required this.achievements,
    required this.shimmerController,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    final unlockedCount = achievements.where((a) => a.isUnlocked).length;
    final unlocked = achievements.where((a) => a.isUnlocked).toList();
    final locked = achievements.where((a) => !a.isUnlocked).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Circular progress card
        _buildProgressRingCard(unlockedCount, achievements.length),
        const SizedBox(height: 24),

        // Unlocked section
        if (unlocked.isNotEmpty) ...[
          _buildSectionHeader('✨ Unlocked', SeedlingColors.seedlingGreen),
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            childAspectRatio: 0.72,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            children: unlocked
                .map((a) => _buildRarityBadge(a, isUnlocked: true))
                .toList(),
          ),
          const SizedBox(height: 24),
        ],

        // Locked section
        if (locked.isNotEmpty) ...[
          _buildSectionHeader('🔒 Locked', SeedlingColors.textSecondary),
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            childAspectRatio: 0.72,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            children: locked
                .map((a) => _buildRarityBadge(a, isUnlocked: false))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildProgressRingCard(int unlocked, int total) {
    final progress = unlocked / total;
    return AnimatedBuilder(
      animation: pulseController,
      builder: (_, __) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              SeedlingColors.seedlingGreen.withValues(alpha: 0.2),
              SeedlingColors.cardBackground,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: SeedlingColors.seedlingGreen.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CustomPaint(
                painter: _XPRingPainter(
                  progress: progress,
                  ringColor: SeedlingColors.seedlingGreen,
                  trackColor: SeedlingColors.morningDew.withValues(alpha: 0.15),
                ),
                child: Center(
                  child: Text(
                    '$unlocked',
                    style: SeedlingTypography.heading2.copyWith(
                      color: SeedlingColors.seedlingGreen,
                      fontSize: 22,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Achievement Progress',
                    style: SeedlingTypography.caption.copyWith(
                      color: SeedlingColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$unlocked of $total Unlocked',
                    style: SeedlingTypography.heading3.copyWith(
                      color: SeedlingColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(progress * 100).toInt()}% complete',
                    style: SeedlingTypography.caption.copyWith(
                      color: SeedlingColors.seedlingGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Row(
      children: [
        Text(
          title,
          style: SeedlingTypography.heading3.copyWith(
            color: color,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildRarityBadge(Achievement a, {required bool isUnlocked}) {
    final rarity = _rarityFor(a.id);
    final rarityColor = _rarityColor(rarity);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            AchievementBadge(achievement: a),
            if (!isUnlocked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: SeedlingColors.background.withValues(alpha: 0.6),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.lock_rounded,
                      color: SeedlingColors.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: rarityColor.withValues(alpha: isUnlocked ? 0.15 : 0.06),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: rarityColor.withValues(alpha: isUnlocked ? 0.5 : 0.15),
            ),
          ),
          child: Text(
            _rarityLabel(rarity),
            style: SeedlingTypography.caption.copyWith(
              fontSize: 7,
              color: isUnlocked
                  ? rarityColor
                  : rarityColor.withValues(alpha: 0.4),
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Activity Tab ──────────────────────────────────────────────────────────────

class _ActivityTab extends ConsumerStatefulWidget {
  final AnimationController shimmerController;

  const _ActivityTab({required this.shimmerController});

  @override
  ConsumerState<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends ConsumerState<_ActivityTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _xpPillController;

  @override
  void initState() {
    super.initState();
    _xpPillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _xpPillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activityAsync = ref.watch(recentActivityProvider);

    return activityAsync.when(
      data: (words) {
        if (words.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Text(
                'No recent activity yet.\nKeep learning! 🌱',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final activities = words.map((word) {
          final isMastered = word.masteryLevel >= 5;
          final String action = isMastered ? 'Mastered' : 'Reviewed';
          final String lang = word.languageCode.toUpperCase();
          final String catStr = word.categoryIds.isNotEmpty
              ? word.categoryIds.first
              : 'General';
          final String cat = catStr.isNotEmpty
              ? catStr[0].toUpperCase() + catStr.substring(1)
              : 'General';
          final int xpEarned = isMastered ? 50 : 10;

          return _ActivityData(
            icon: isMastered ? Icons.star_rounded : Icons.book_rounded,
            title: '$action "${word.translation}"',
            subtitle: '$lang • $cat',
            time: 'Recently',
            xp: xpEarned,
            isMastered: isMastered,
            color: isMastered
                ? SeedlingColors.autumnGold
                : SeedlingColors.seedlingGreen,
          );
        }).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            Text('Recent Activity', style: SeedlingTypography.heading3),
            const SizedBox(height: 20),
            ...activities.asMap().entries.map(
              (e) => _buildTimelineItem(e.value, e.key, activities.length),
            ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: SeedlingColors.seedlingGreen),
      ),
      error: (_, __) => const Center(child: Text('Error loading activity')),
    );
  }

  Widget _buildTimelineItem(_ActivityData activity, int index, int total) {
    final isLast = index == total - 1;

    return AnimatedBuilder(
      animation: _xpPillController,
      builder: (_, __) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline column
            Column(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        activity.color.withValues(alpha: 0.25),
                        SeedlingColors.cardBackground,
                      ],
                    ),
                    border: Border.all(
                      color: activity.color.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Center(
                    child: Icon(activity.icon, color: activity.color, size: 18),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          SeedlingColors.morningDew.withValues(alpha: 0.3),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: SeedlingColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: activity.color.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity.title,
                              style: SeedlingTypography.body.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              activity.subtitle,
                              style: SeedlingTypography.caption,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activity.time,
                              style: SeedlingTypography.caption.copyWith(
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // XP Pill — bounces in from right
                      Transform.translate(
                        offset: Offset(20 * (1 - _xpPillController.value), 0),
                        child: Opacity(
                          opacity: _xpPillController.value,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  activity.color.withValues(alpha: 0.3),
                                  activity.color.withValues(alpha: 0.15),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: activity.color.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              '+${activity.xp} XP',
                              style: SeedlingTypography.caption.copyWith(
                                fontWeight: FontWeight.bold,
                                color: activity.color,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ActivityData {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final int xp;
  final bool isMastered;
  final Color color;

  _ActivityData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.xp,
    required this.isMastered,
    required this.color,
  });
}

// ── Custom Painters ───────────────────────────────────────────────────────────

class _XPRingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color trackColor;

  _XPRingPainter({
    required this.progress,
    this.ringColor = SeedlingColors.autumnGold,
    this.trackColor = const Color(0x22FFD54F),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = (size.width / 2) - 8;
    const startAngle = -math.pi / 2;

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = trackColor
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc
    if (progress > 0) {
      final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
      final shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + 2 * math.pi,
        colors: [ringColor, ringColor.withValues(alpha: 0.6), ringColor],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);

      canvas.drawArc(
        rect,
        startAngle,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..shader = shader
          ..strokeWidth = 8
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _XPRingPainter old) => old.progress != progress;
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxVal = data.reduce(math.max);
    final minVal = data.reduce(math.min);
    final range = (maxVal - minVal).clamp(1.0, double.infinity);

    final barWidth = size.width / (data.length * 2 - 1);

    for (int i = 0; i < data.length; i++) {
      final normalised = (data[i] - minVal) / range;
      final barH = (normalised * size.height * 0.85) + size.height * 0.1;
      final x = i * barWidth * 2;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - barH, barWidth, barH),
        const Radius.circular(2),
      );

      canvas.drawRRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            colors: [color, color.withValues(alpha: 0.3)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(rect.outerRect),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) => false;
}

// ── Sliver Tab Bar Delegate ───────────────────────────────────────────────────

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => 66;

  @override
  double get maxExtent => 66;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return tabBar;
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}

// ── Data Classes ──────────────────────────────────────────────────────────────

class UserProfileData {
  final int level;
  final int currentXP;
  final int xpForNextLevel;
  final int streak;
  final int totalWords;
  final int totalMinutes;
  final int achievementsUnlocked;
  final int totalAchievements;
  final List<Achievement> achievements;

  UserProfileData({
    required this.level,
    required this.currentXP,
    required this.xpForNextLevel,
    required this.streak,
    required this.totalWords,
    required this.totalMinutes,
    required this.achievementsUnlocked,
    required this.totalAchievements,
    required this.achievements,
  });
}
